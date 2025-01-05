# frozen_string_literal: true

module Recordings
  ##
  # WindDirectionInferenceService attempts to deduce the prevailing wind direction
  # for a given Recording purely from the boat's heading data. Its logic is heuristic:
  #
  # ### The High‐Level Heuristic:
  #   1. Identify times when the boat was "close hauled" (stable heading) on starboard tack.
  #   2. Identify times when the boat was close hauled on port tack (roughly ~80–100° difference
  #      from the starboard heading, or ~180° from starboard if you consider the geometry).
  #   3. Collect **multiple** stable runs for each possible starboard heading or port heading.
  #   4. Instead of picking the single largest run, we pick whichever starboard‐port pair
  #      yields the maximum **number** of stable runs (i.e. the pair that appears most frequently),
  #      which is more likely a genuine upwind scenario repeated across tacks.
  #   5. Compute final wind direction from the selected starboard & port headings, factoring in
  #      a typical close‐hauled offset (CLOSE_HAULED_ANGLE). Then round the result to the nearest
  #      NEAREST_DEGREE (e.g. 5 or 10).
  #
  # ### Memory & Performance:
  #   - Uses `.find_in_batches` to read RecordedLocations in increments (batch_size=200).
  #   - Accumulates "stable runs" in memory, but each run is just a few fields (avg_heading, etc.).
  #   - Circular averaging is used to handle wraparound near 0..359 boundaries.
  #
  # ### Implementation Outline:
  #   - We build "stable runs" (where the heading doesn't vary by more than
  #     STABLE_HEADING_DIFFERENCE) for at least MIN_STABLE_POINTS in a row.
  #   - We cluster these stable runs (like “starboard cluster #1,” “starboard cluster #2,” etc.)
  #     by grouping them if they’re within CLUSTER_HEADING_TOLERANCE of each other.
  #   - We then find pairs of these starboard vs. port clusters that differ ~80–100°,
  #     picking the pair that yields the *largest total count of stable runs*.
  #   - Finally, we compute the approximate wind direction from those clusters (midpoint minus
  #     or plus the CLOSE_HAULED_ANGLE) and round it.
  #
  class WindDirectionInferenceService
    # -----------------------------
    #       CONFIGURABLE CONSTANTS
    # -----------------------------

    # The maximum heading difference within a single stable run
    STABLE_HEADING_DIFFERENCE = 5.0

    # The minimum number of consecutive points needed to form one stable run
    MIN_STABLE_POINTS = 30

    # When grouping stable runs into “clusters,” runs whose average headings differ
    # by < CLUSTER_HEADING_TOLERANCE are considered the *same* cluster (e.g. starboard #1).
    CLUSTER_HEADING_TOLERANCE = 10.0

    # For starboard vs. port classification, we consider stable run headings
    # that differ by ~80..100 degrees as being on opposite tacks.
    MIN_STARBOARD_PORT_DIFF = 80
    MAX_STARBOARD_PORT_DIFF = 100

    # Typical close‐hauled offset from the wind, e.g. ~45°
    CLOSE_HAULED_ANGLE = 45

    # Final rounding increment for wind direction
    NEAREST_DEGREE = 5

    def initialize(recording_id)
      @recording_id = recording_id
    end

    ##
    # @return [Integer, nil] The inferred wind direction in degrees (0..359) or nil if unknown.
    def call
      recording = Recording.find_by(id: @recording_id)
      return unless recording

      # Step 1: Gather stable runs
      stable_runs = collect_stable_runs(recording)
      return nil if stable_runs.empty?

      # Step 2: Group stable runs into clusters of similar headings (± CLUSTER_HEADING_TOLERANCE).
      # Example: if we have runs with headings 10°, 12°, 14°, they become one “starboard cluster #1.”
      # If we have runs with headings 190°, 187°, 193°, that might be “port cluster #2.”
      clusters = cluster_stable_runs(stable_runs)

      # Step 3: Among these clusters, find the starboard vs. port pair that differs ~80..110°,
      # and yields the largest total number of stable runs. This is an attempt to pick
      # the “most frequently used” upwind headings (the boat likely tacked multiple times).
      best_pair = find_best_pair(clusters)

      return nil unless best_pair
      s_cluster, p_cluster = best_pair

      # Step 4: Compute approximate wind direction. Suppose starboard heading ~HS, port heading ~HP.
      # We'll do a simple formula:
      #   starboard guess = HS + CLOSE_HAULED_ANGLE
      #   port guess      = HP - CLOSE_HAULED_ANGLE
      # Then average them with a circular midpoint.
      s_guess = (s_cluster[:heading] + CLOSE_HAULED_ANGLE) % 360
      p_guess = (p_cluster[:heading] - CLOSE_HAULED_ANGLE) % 360
      raw_wind = midpoint_degree(s_guess, p_guess)

      # Step 5: Round to nearest NEAREST_DEGREE
      final_wind = round_to_nearest(raw_wind, NEAREST_DEGREE)

      return unless final_wind.is_a? Integer
      recording.update!(wind_direction_degrees: final_wind)
    rescue => e
      ErrorNotifierService.notify(e, recording_id: @recording_id)
      nil
    end

    private

    # --------------------------------------------------------------------------
    #  1) Collect stable runs
    # --------------------------------------------------------------------------

    ##
    # Streams over headings in batches, building stable runs (≥ MIN_STABLE_POINTS).
    #
    # @param recording [Recording]
    # @return [Array<Hash>] each hash: { avg_heading:, count:, start_at:, end_at: }
    #
    def collect_stable_runs(recording)
      runs = []
      current_run = []
      last_avg = nil

      recording.recorded_locations
               .processed
               .chronological
               .find_in_batches(batch_size: 200) do |batch|
        batch.each do |loc|
          next unless loc.heading

          heading = loc.heading.to_f
          if current_run.empty?
            # start new stable run
            current_run << { heading: heading, time: loc.recorded_at }
            last_avg = heading
            next
          end

          # check if this heading fits stable definition w.r.t. last_avg
          if heading_difference(last_avg, heading).abs <= STABLE_HEADING_DIFFERENCE
            current_run << { heading: heading, time: loc.recorded_at }
            last_avg = reaverage_run(current_run)
          else
            # finalize if big enough
            finalize_if_sizable(runs, current_run)
            # start new
            current_run = [ { heading: heading, time: loc.recorded_at } ]
            last_avg = heading
          end
        end
      end

      # finalize any leftover
      finalize_if_sizable(runs, current_run)

      runs
    end

    ##
    # If a run has >= MIN_STABLE_POINTS, we store it with average heading.
    # Otherwise discard it as too small / ephemeral.
    #
    def finalize_if_sizable(runs, array_of_points)
      return if array_of_points.size < MIN_STABLE_POINTS

      avg = average_heading_circular(array_of_points.map { |p| p[:heading] })
      runs << {
        avg_heading: normalize_degree(avg),
        count: array_of_points.size,
        start_at: array_of_points.first[:time],
        end_at: array_of_points.last[:time]
      }
    end

    ##
    # Recomputes the average heading of a run.
    # We do a circular average of the entire run for correctness.
    #
    def reaverage_run(run_points)
      headings = run_points.map { |p| p[:heading] }
      average_heading_circular(headings)
    end

    # --------------------------------------------------------------------------
    #  2) Group stable runs into heading clusters
    # --------------------------------------------------------------------------

    ##
    # Groups stable runs by their avg_heading if they are within ±CLUSTER_HEADING_TOLERANCE.
    # Example: runs with avg_heading=10°,12°,14° => single cluster with heading ~12°,
    # containing 3 runs total. We store how many runs are in each cluster, etc.
    #
    # @param stable_runs [Array<Hash>]
    # @return [Array<Hash>] each cluster: { heading:, runs_count:, run_headings:[], ... }
    #
    def cluster_stable_runs(stable_runs)
      clusters = []

      stable_runs.each do |run|
        h = run[:avg_heading]

        # Attempt to find an existing cluster within ±CCLUSTER_HEADING_TOLERANCE of h
        found_cluster = nil
        clusters.each do |c|
          if heading_difference(c[:heading], h).abs <= CLUSTER_HEADING_TOLERANCE
            found_cluster = c
            break
          end
        end

        if found_cluster
          # add this run to that cluster
          found_cluster[:runs_count] += 1
          found_cluster[:all_headings] << h
          # update cluster's heading to reflect new average
          found_cluster[:heading] = average_heading_circular(found_cluster[:all_headings])
        else
          # create a new cluster
          clusters << {
            heading: h,
            runs_count: 1,
            all_headings: [ h ]
          }
        end
      end

      # finalize cluster headings properly
      clusters.each do |c|
        c[:heading] = normalize_degree(average_heading_circular(c[:all_headings]))
      end

      clusters
    end

    # --------------------------------------------------------------------------
    #  3) Find the best starboard‐port pair by # of stable runs
    # --------------------------------------------------------------------------

    ##
    # Finds two clusters that differ by ~80..110° and yields the *largest total runs_count*.
    # This approach picks the starboard vs. port headings that the boat used the **most** times.
    #
    # @param clusters [Array<Hash>] each: { heading:, runs_count:, all_headings:[] }
    # @return [Array<Hash>, nil] e.g. [ { heading: X, runs_count: N }, { heading: Y, runs_count: M } ]
    #
    def find_best_pair(clusters)
      return nil if clusters.size < 2

      best_pair = nil
      best_sum = 0

      clusters.combination(2).each do |c1, c2|
        diff = heading_difference(c1[:heading], c2[:heading]).abs
        if diff >= MIN_STARBOARD_PORT_DIFF && diff <= MAX_STARBOARD_PORT_DIFF
          pair_sum = c1[:runs_count] + c2[:runs_count]
          if pair_sum > best_sum
            best_sum = pair_sum
            # Sort by heading so smaller heading is first
            best_pair = c1[:heading] < c2[:heading] ? [ c1, c2 ] : [ c2, c1 ]
          end
        end
      end

      best_pair
    end

    # --------------------------------------------------------------------------
    #  4) Utilities (heading math)
    # --------------------------------------------------------------------------

    ##
    # average_heading_circular uses a vector-based approach to handle wrap properly
    #
    def average_heading_circular(headings)
      return 0 if headings.empty?

      sum_x = 0.0
      sum_y = 0.0
      headings.each do |h|
        rad = h * Math::PI / 180.0
        sum_x += Math.cos(rad)
        sum_y += Math.sin(rad)
      end
      avg_rad = Math.atan2(sum_y, sum_x)
      (avg_rad * 180.0 / Math::PI) % 360
    end

    ##
    # heading_difference => minimal difference in -180..180
    #
    def heading_difference(h1, h2)
      diff = (h2 - h1) % 360
      diff > 180 ? diff - 360 : diff
    end

    ##
    # midpoint_degree => circular midpoint of two angles
    #
    def midpoint_degree(a, b)
      a_rad = a * Math::PI / 180
      b_rad = b * Math::PI / 180
      x = (Math.cos(a_rad) + Math.cos(b_rad)) / 2.0
      y = (Math.sin(a_rad) + Math.sin(b_rad)) / 2.0
      deg = (Math.atan2(y, x) * 180 / Math::PI) % 360
      deg
    end

    ##
    # round_to_nearest => round an angle to nearest multiple (e.g. NEAREST_DEGREE=5)
    #
    def round_to_nearest(d, bucket)
      angle = (d / bucket).round * bucket
      angle % 360
    end

    ##
    # normalize_degree => ensures angle is in 0..359
    #
    def normalize_degree(d)
      d % 360
    end
  end
end
