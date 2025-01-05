# app/services/recordings/wind_direction_inference_service.rb
# frozen_string_literal: true

module Recordings
  ##
  # WindDirectionInferenceService attempts to deduce the prevailing wind direction
  # for a given Recording purely from the boat's heading data. Its logic is heuristic:
  #
  # ### The High‐Level Heuristic:
  #   1. Identify times when the boat was "close hauled" on starboard tack
  #      (meaning the boat's heading is somewhat consistent and possibly ~40–50° off
  #      the wind, but we don't know the wind yet, so we approximate).
  #
  #   2. Identify times when the boat was close hauled on port tack
  #      (which should be roughly ~180° different from the starboard heading, or
  #      ~90° if factoring the actual geometry and the boat's pointing ability).
  #
  #   3. Gather these starboard vs. port headings in small "clusters" of stable,
  #      consistent headings. We do this with a streaming, memory‐light approach:
  #        - We'll look for runs of headings that remain fairly stable
  #        - We'll separate runs that differ by ~80–100° from starboard vs. port
  #
  #   4. Average out the starboard close‐hauled cluster and the port close‐hauled cluster.
  #      The wind direction is roughly halfway between them plus or minus the boat's
  #      normal close‐hauled offset (~45°). For instance, if the starboard heading
  #      cluster is ~ 45°, and port cluster is ~ 225°, that suggests the boat is
  #      sailing about 45° off the wind on each side, so wind is ~ 0° (North).
  #
  #   5. We then round to the nearest 5 or 10 degrees. In the real world, you can refine
  #      this logic or gather more advanced data (e.g. velocity, real‐time tacks).
  #
  # ### Memory & Performance:
  #   - We use `.find_in_batches` to read RecordedLocations in increments (batch_size=200).
  #   - We keep a small rolling "stability" buffer to detect close‐hauled segments,
  #     discarding older data once we've recognized a stable run or once it's too old.
  #   - The final output is either an integer from 0..359 or nil if we cannot deduce it.
  #
  # ### Implementation Outline:
  #   - We build "stable runs" of headings (where the heading doesn't vary by more than
  #     STABLE_HEADING_DIFFERENCE) for at least MIN_STABLE_POINTS in a row.
  #   - We label each stable run as "starboard cluster" or "port cluster" if we see
  #     that it’s ~90–110° different from an opposite cluster (heuristic).
  #   - We then pick the largest starboard cluster and the largest port cluster and
  #     compute the approximate wind direction from them. Finally, we round to the
  #     nearest NEAREST_DEGREE multiple.
  #
  class WindDirectionInferenceService
    # -----------------------------
    #       CONFIGURABLE CONSTANTS
    # -----------------------------

    # The maximum heading difference within a "stable run"
    STABLE_HEADING_DIFFERENCE = 5.0

    # The minimum number of consecutive points needed to form a "stable run"
    MIN_STABLE_POINTS = 10

    # For cluster classification: starboard vs. port headings should differ ~90°.
    # We allow some wiggle. E.g., ~80–110° difference is typical if the boat doesn't
    # point very close. You can tweak these as needed.
    MIN_STARBOARD_PORT_DIFF = 80
    MAX_STARBOARD_PORT_DIFF = 110

    # Boat's approximate close-hauled angle: e.g. ~45° off the wind.
    # We'll apply a basic formula: wind_dir = (avg_heading - CLOSE_HAULED_ANGLE)

    CLOSE_HAULED_ANGLE = 45

    # If we find stable starboard vs stable port headings, we guess the wind
    # is about halfway between them minus or plus this angle. E.g.:
    #   starboard heading = 10°, port heading = 190°, midpoint=100°,
    #   wind= (100° - 45°)=55°, or something.
    # We'll do a formula.

    # Finally, we round the resulting wind direction to NEAREST_DEGREE
    NEAREST_DEGREE = 5

    def initialize(recording_id)
      @recording_id = recording_id
    end

    ##
    # @return [Integer, nil] The inferred wind direction in degrees (0..359) or nil if unknown.
    def call
      recording = Recording.find_by(id: @recording_id)
      return unless recording

      # We'll store "stable runs" in an Array of { avg_heading:, count:, start_at:, end_at: }
      stable_runs = collect_stable_runs(recording)

      # Now, separate stable runs roughly into "starboard" or "port" close‐hauled
      # if their headings differ by ~180° or if we find pairs ~90° from each other.
      # This is heuristic. We'll pick the two biggest stable runs that differ ~90-110°.
      # In actual practice, you might have a more advanced approach.

      s_cluster, p_cluster = find_best_starboard_port(stable_runs)

      Rails.logger.info "Starboard cluster: #{s_cluster}."
      Rails.logger.info "Port cluster: #{p_cluster}."

      return nil unless s_cluster && p_cluster

      # 1) Let's say starboard heading ~ s_cluster[:avg_heading]
      # 2) port heading ~ p_cluster[:avg_heading]
      # 3) The boat is probably pointing ~CLOSE_HAULED_ANGLE off the wind on either side.
      #    So if starboard heading is Hs, we guess wind ~ Hs + CLOSE_HAULED_ANGLE
      #    or if port heading is Hp, we guess wind ~ Hp - CLOSE_HAULED_ANGLE
      # We'll unify them by taking the midpoint between those two guesses.

      s_guess = (s_cluster[:avg_heading] + CLOSE_HAULED_ANGLE) % 360
      p_guess = (p_cluster[:avg_heading] - CLOSE_HAULED_ANGLE) % 360
      raw_wind = midpoint_degree(s_guess, p_guess)

      # Round to nearest 10 deg by default
      final_wind = round_to_nearest(raw_wind, NEAREST_DEGREE)
      Rails.logger.info "Wind direction: #{final_wind}."

      return unless final_wind.is_a? Integer
      recording.update!(wind_direction_degrees: final_wind)
    rescue => e
      ErrorNotifierService.notify(e, recording_id: @recording_id)
      nil
    end

    private

    ##
    # collect_stable_runs streams over all headings, building "stable runs."
    # A stable run is a sequence of consecutive headings that do not differ from
    # the run's average by more than STABLE_HEADING_DIFFERENCE. Once we break that
    # threshold, we finalize the run and start a new one.
    #
    # @return [Array<Hash>] each hash has :avg_heading, :count, :start_at, :end_at
    #
    def collect_stable_runs(recording)
      runs = []
      current_run = []
      last_avg    = nil

      recording.recorded_locations
               .processed
               .chronological
               .find_in_batches(batch_size: 100) do |batch|
        batch.each do |loc|
          next unless loc.heading

          heading = loc.heading.to_f
          if current_run.empty?
            # start new run
            current_run << { heading: heading, time: loc.recorded_at }
            last_avg    = heading
            next
          end

          # check if this heading fits the "stable" definition w.r.t. last_avg
          if heading_difference(last_avg, heading).abs <= STABLE_HEADING_DIFFERENCE
            current_run << { heading: heading, time: loc.recorded_at }
            # update last_avg
            last_avg = recompute_avg(current_run, last_avg, heading)
          else
            # finalize if big enough
            finalize_if_sizable(runs, current_run)
            # start new run
            current_run = [ { heading: heading, time: loc.recorded_at } ]
            last_avg    = heading
          end
        end
      end

      # end of data => finalize any leftover run
      finalize_if_sizable(runs, current_run)

      runs
    end

    ##
    # finalize_if_sizable takes the array of points in a run. If it's >= MIN_STABLE_POINTS,
    # we compute the average heading and store it. Otherwise, discard it.
    #
    def finalize_if_sizable(runs, arr)
      return if arr.size < MIN_STABLE_POINTS

      # average heading in a naive sense (We have to do circular averaging though!)
      # For small angles, a naive average is fine. But if headings cross 0..359 boundary,
      # we should do a sine/cosine approach. For brevity, let's do the naive approach
      # and hope we don't cross 359->0 boundary too often.

      # A more robust approach is to convert each heading to a vector (sin/cos),
      # average them, then convert back to degrees.

      avg = average_heading_circular(arr.map { |p| p[:heading] })
      runs << {
        avg_heading: normalize_degree(avg),
        count:       arr.size,
        start_at:    arr.first[:time],
        end_at:      arr.last[:time]
      }
    end

    ##
    # average_heading_circular does a proper vector-based average to avoid issues
    # around 359->0 wrap.
    #
    def average_heading_circular(headings)
      sum_x = 0.0
      sum_y = 0.0
      headings.each do |h|
        rad = (h * Math::PI / 180.0)
        sum_x += Math.cos(rad)
        sum_y += Math.sin(rad)
      end
      avg_rad = Math.atan2(sum_y, sum_x)
      deg     = (avg_rad * 180.0 / Math::PI) % 360
      deg
    end

    ##
    # recompute_avg is a cheap incremental approach when we add one heading at a time
    # to a stable run. We do the “exact” approach by re-summing. For better performance,
    # you could do a vector-based approach incrementally, but let's keep it simple for clarity.
    #
    def recompute_avg(run, old_avg, new_heading)
      # naive approach: re-average everything
      headings = run.map { |p| p[:heading] }
      average_heading_circular(headings)
    end

    ##
    # find_best_starboard_port picks two stable runs that differ by ~180°, or ~90° for the
    # half-angle approach. This is the big heuristic. We’ll try a simpler approach:
    #   - We loop through each pair of stable runs
    #   - If they differ by ~ (180 ± something) or we see them as starboard vs. port
    #   - We pick the pair that has the largest total .count sum
    #
    # We'll do a simplified approach checking ~80..110 difference from "starboard" to "port"
    # if we assume close-hauled is ~ 90° difference.
    #
    def find_best_starboard_port(runs)
      best_pair     = [ nil, nil ]
      best_combined = 0
      # naive pairwise approach
      runs.combination(2).each do |r1, r2|
        diff = heading_difference(r1[:avg_heading], r2[:avg_heading]).abs
        # e.g. 85..95 might be a good starboard vs port difference
        if diff >= MIN_STARBOARD_PORT_DIFF && diff <= MAX_STARBOARD_PORT_DIFF
          combined = r1[:count] + r2[:count]
          if combined > best_combined
            best_combined = combined
            # We’ll label the smaller heading as "starboard" just arbitrarily
            # or we can keep the original order. Let's do it by which heading < which.
            if r1[:avg_heading] < r2[:avg_heading]
              best_pair = [ r1, r2 ]
            else
              best_pair = [ r2, r1 ]
            end
          end
        end
      end
      best_pair
    end

    ##
    # heading_difference returns minimal difference in -180..180
    #
    def heading_difference(h1, h2)
      diff = (h2 - h1) % 360
      diff > 180 ? diff - 360 : diff
    end

    ##
    # midpoint_degree is a simple function that finds the circular midpoint of two angles
    #
    def midpoint_degree(a, b)
      # vector approach again
      a_rad = a * Math::PI / 180
      b_rad = b * Math::PI / 180
      x = (Math.cos(a_rad) + Math.cos(b_rad)) / 2.0
      y = (Math.sin(a_rad) + Math.sin(b_rad)) / 2.0
      deg = (Math.atan2(y, x) * 180 / Math::PI) % 360
      deg
    end

    ##
    # normalizes an angle to 0..359
    #
    def normalize_degree(d)
      d % 360
    end

    ##
    # round_to_nearest rounds an angle `d` to the nearest multiple of `bucket` (e.g. 10°).
    #
    def round_to_nearest(d, bucket)
      (d / bucket).round * bucket % 360
    end
  end
end
