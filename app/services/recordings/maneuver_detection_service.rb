# app/services/recordings/maneuver_detection_service.rb
# frozen_string_literal: true

module Recordings
  ##
  # ManeuverDetectionService scans through a Recording's RecordedLocations to detect maneuvers.
  #
  # ### Performance & Memory
  #
  #  - Uses `find_in_batches` to retrieve RecordedLocations in chunks (batch_size=100 by default).
  #    This prevents loading the entire dataset into memory at once.
  #  - Maintains a small in‐memory array of "turn points" (`turn_points`) to represent the current
  #    ongoing turn. We drop old points that fall outside a time window (`WINDOW_SECONDS`).
  #  - We finalize exactly one Maneuver when the boat stops turning or reverses turning direction
  #    for a sustained period, thus preventing multiple false‐alarm maneuvers in a single turn.
  #
  # ### Key Features
  #
  #  - **Consecutive Sign‐Flips**: We don't finalize a turn on a single sign flip of the heading‐delta,
  #    to avoid random sensor noise. Instead, we require sign changes across several consecutive
  #    points (`TURN_DIRECTION_FLIP_REQUIRED_COUNT`) or the boat going stable to finalize the turn.
  #  - **Stable Heading**: If the heading change is below a small threshold (`STABLE_DELTA_THRESHOLD`)
  #    for enough consecutive points (`STABLE_CONSECUTIVE_PTS`), we consider the turn ended.
  #  - **Configurable Thresholds**: All thresholds (angle, stable counts, etc.) are constants,
  #    so we can tune them quickly in production.
  #
  # ### Data Flow
  #
  # For each batch of RecordedLocations:
  #   1. If no turn is in progress, we initialize one.
  #   2. Accumulate heading deltas for each new location.
  #   3. If turning direction changes consistently or we go stable, finalize the turn
  #      if it exceeds the minimum heading change threshold (`MIN_ABS_CUMULATIVE`).
  #   4. Write out exactly one Maneuver to the `maneuvers` table.
  #
  # ### Classification
  #
  # Classification is done with `classify_maneuver(total_change)`. By default:
  #   - >= 315° => "penalty_spin"
  #   - >= 120° => "rounding"
  #   - >= 70°  => "tack"
  #   - >= 30°  => "jibe"
  #   - else    => "unknown"
  #
  class ManeuverDetectionService
    # -------------------------
    #   CONFIGURABLE CONSTANTS
    # -------------------------

    # The maximum size of the rolling time window for points we keep in memory for the current turn
    WINDOW_SECONDS = 15

    # Degrees difference below which heading changes are considered "stable"
    STABLE_DELTA_THRESHOLD = 5.0

    # Number of consecutive stable heading deltas needed to conclude "the turn has ended"
    STABLE_CONSECUTIVE_PTS = 3

    # The minimum total absolute heading change (deg) required to create a maneuver
    MIN_ABS_CUMULATIVE = 30

    # Number of consecutive sign flips needed to confirm we really reversed turning direction
    # (helps avoid random sign flips from noise)
    TURN_DIRECTION_FLIP_REQUIRED_COUNT = 3

    # -------------------------
    #        INITIALIZATION
    # -------------------------
    def initialize(recording_id)
      @recording = Recording.find(recording_id)
    end

    # Main entry point
    def call
      return unless @recording

      # If re-running, wipe old maneuvers
      @recording.maneuvers.delete_all

      detect_maneuvers
    rescue => e
      ErrorNotifierService.notify(e, recording_id: @recording&.id)
    end

    private

    ##
    # The primary detection routine, implemented with a streaming / batch approach
    # to avoid reading all RecordedLocations into memory at once.
    #
    def detect_maneuvers
      # We'll keep a small array describing the boat's ongoing turn:
      #   turn_points: [ { loc, heading, cumulative }, ... ]
      # plus some counters for detecting sign flips, stable counts, etc.
      turn_points      = []
      prev_heading     = nil
      stable_count     = 0
      current_sign     = 0
      sign_flip_count  = 0

      @recording.recorded_locations
                .processed
                .not_simplified
                .chronological
                .find_in_batches(batch_size: 100) do |batch|
        batch.each do |loc|
          # If no points yet, initialize the current turn
          if turn_points.empty?
            turn_points << build_turn_point(loc, 0.0)
            prev_heading = loc.heading.to_f
            next
          end

          # 1) Compute heading delta from the previous heading
          new_heading = loc.heading.to_f
          delta       = signed_heading_delta(prev_heading, new_heading)
          prev_heading = new_heading

          # 2) Accumulate in 'turn_points'
          new_cumulative = turn_points.last[:cumulative] + delta
          turn_points << build_turn_point(loc, new_cumulative)

          # 3) Trim old points outside the rolling time window
          trim_old_points(turn_points, loc.recorded_at)

          # 4) Detect turning sign
          this_sign = delta <=> 0  # -1 if negative, 0 if zero, +1 if positive
          unless this_sign == 0
            if current_sign == 0
              # first nonzero sign
              current_sign = this_sign
            elsif this_sign != current_sign
              # the sign differs from last known turning direction
              sign_flip_count += 1
            else
              # same sign as before => reset sign_flip_count
              sign_flip_count = 0
            end
          end

          # 5) Track "stable heading" if delta < STABLE_DELTA_THRESHOLD
          if delta.abs < STABLE_DELTA_THRESHOLD
            stable_count += 1
          else
            stable_count = 0
          end

          # 6) If we have enough sign flips to confirm a real direction reversal, finalize
          #    or if we've gone stable for enough consecutive points, finalize
          if sign_flip_count >= TURN_DIRECTION_FLIP_REQUIRED_COUNT || stable_count >= STABLE_CONSECUTIVE_PTS
            finalize_turn(turn_points)
            # Reset the arrays and counters for a fresh turn
            turn_points      = [ turn_points.last ] # keep the last point as the start of a new turn
            stable_count     = 0
            sign_flip_count  = 0
            current_sign     = 0
          end
        end
      end

      # End of data => finalize any leftover turn
      finalize_turn(turn_points) if turn_points.size >= 2
    end

    ##
    # Build a lightweight struct for each turn point to reduce memory usage.
    #
    def build_turn_point(loc, cumulative)
      {
        loc:        loc,
        heading:    loc.heading.to_f,
        cumulative: cumulative
      }
    end

    ##
    # Trim old points from the front if they're older than current_time - WINDOW_SECONDS
    #
    def trim_old_points(points, current_time)
      cutoff = current_time - WINDOW_SECONDS
      while points.size > 1 && points.first[:loc].recorded_at < cutoff
        points.shift
      end
    end

    ##
    # Finalizes the ongoing turn by measuring total heading change and, if large enough,
    # writing exactly one Maneuver row to the DB.
    # We interpret "halfway" in the turn for lat/long/time to store in the Maneuver record.
    #
    def finalize_turn(points)
      return if points.size < 2

      # net heading change from first->last in the turn
      total_change = points.last[:cumulative] - points.first[:cumulative]
      return if total_change.abs < MIN_ABS_CUMULATIVE

      # find halfway
      half_target = points.first[:cumulative] + (total_change / 2.0)
      half_index  = find_halfway_index(points, half_target)
      half_entry  = interpolate_halfway_position(points, half_index, half_target)

      # persist
      create_maneuver(points, total_change, half_entry)
    end

    ##
    # Find the array index within +points+ where the cumulative crosses +half_target+
    #
    def find_halfway_index(points, half_target)
      points.each_with_index do |entry, idx|
        return idx if half_target >= 0 && entry[:cumulative] >= half_target
        return idx if half_target <  0 && entry[:cumulative] <= half_target
      end
      points.size - 1
    end

    ##
    # Interpolate between points[index-1] and points[index] for exact halfway time/position
    #
    def interpolate_halfway_position(points, index, half_target)
      return build_interpolated(points[index], half_target) if index <= 0 || index >= points.size

      prev_entry    = points[index - 1]
      current_entry = points[index]

      prev_cum = prev_entry[:cumulative]
      curr_cum = current_entry[:cumulative]
      delta_cum = (curr_cum - prev_cum).abs
      return build_interpolated(current_entry, half_target) if delta_cum < 1e-5

      # linear fraction
      frac = (half_target - prev_cum) / (curr_cum - prev_cum)

      # times
      t0          = prev_entry[:loc].recorded_at.to_f
      t1          = current_entry[:loc].recorded_at.to_f
      occurred_at = Time.at(t0 + frac * (t1 - t0))

      # lat/lon
      lat = lerp(prev_entry[:loc].adjusted_latitude.to_f,  current_entry[:loc].adjusted_latitude.to_f,  frac)
      lon = lerp(prev_entry[:loc].adjusted_longitude.to_f, current_entry[:loc].adjusted_longitude.to_f, frac)

      {
        loc:        nil,
        cumulative: half_target,
        occurred_at: occurred_at,
        lat: lat,
        lon: lon
      }
    end

    ##
    # If we can't interpolate, just wrap the existing point's data for the "halfway" placeholder
    #
    def build_interpolated(entry, half_target)
      {
        loc: entry[:loc],
        cumulative: half_target,
        occurred_at: entry[:loc].recorded_at,
        lat: entry[:loc].adjusted_latitude.to_f,
        lon: entry[:loc].adjusted_longitude.to_f
      }
    end

    ##
    # Actually create a Maneuver record in the DB
    #
    def create_maneuver(points, total_change, half_entry)
      # classify the turn type
      maneuver_type = classify_maneuver(total_change)
      conf          = compute_confidence(points, total_change)

      if half_entry[:loc]
        lat = half_entry[:loc].adjusted_latitude.to_f
        lon = half_entry[:loc].adjusted_longitude.to_f
        t   = half_entry[:loc].recorded_at
      else
        lat = half_entry[:lat]
        lon = half_entry[:lon]
        t   = half_entry[:occurred_at]
      end

      Maneuver.create!(
        recording:  @recording,
        cumulative_heading_change: total_change.round(2),
        latitude:   lat.round(6),
        longitude:  lon.round(6),
        occurred_at: t,
        maneuver_type: maneuver_type,
        confidence: conf
      )
    end

    ##
    # Classify a maneuver based on the magnitude of heading change
    #
    def classify_maneuver(total_change)
      abs_change = total_change.abs
      return "penalty_spin" if abs_change >= 315
      return "rounding"     if abs_change >= 120
      return "tack"         if abs_change >= 70
      return "jibe"         if abs_change >= 30
      "unknown"
    end

    ##
    # Confidence metric: bigger arcs + more data points => higher confidence
    #
    def compute_confidence(points, total_change)
      # clamp to [0..1]
      points_factor  = [ points.size.to_f / 15.0, 1.0 ].min
      heading_factor = [ total_change.abs / 180.0, 1.0 ].min
      raw_conf       = points_factor + heading_factor
      [ raw_conf, 1.0 ].min.round(3)
    end

    ##
    # Returns heading difference in range -180..180, so turning from
    # heading 350 -> 10 returns +20, not +360
    #
    def signed_heading_delta(h1, h2)
      diff = (h2 - h1) % 360
      diff > 180 ? diff - 360 : diff
    end

    ##
    # Linear interpolation
    #
    def lerp(a, b, fraction)
      a + (b - a) * fraction
    end
  end
end
