# frozen_string_literal: true

module Recordings
  ##
  # ManeuverDetectionService is responsible for detecting key sailing maneuvers
  # (tacks, jibes, roundings, penalty spins, etc.) from raw heading data.
  #
  # It processes a boat's recorded location/heading data in **batches** to avoid
  # loading everything at once. It maintains a **small sliding buffer** of recent
  # points (up to WINDOW_SECONDS in age). Once it detects that the boat has
  # completed a turn (i.e. by becoming stable or reversing direction), it
  # finalizes exactly one Maneuver record in the DB if the heading change is big enough.
  #
  # ### Heuristics
  #
  # 1. **Tack**:
  #    - The boat was sailing "upwind" (heading near ~wind_direction ± HEAD_TO_WIND_MARGIN),
  #      then crosses to the other side of wind_direction, and becomes stable.
  #    - If wind direction is unknown, we fallback to "≥ TACK_ANGLE numeric threshold."
  #
  # 2. **Jibe**:
  #    - The boat was sailing "downwind" (~wind_direction ± DEAD_DOWNWIND_MARGIN),
  #      then crosses to the other side, and becomes stable.
  #    - If wind direction is unknown, fallback to "≥ JIBE_ANGLE numeric threshold."
  #
  # 3. **Penalty Spin**:
  #    - The boat performs a tack + jibe in close succession in the same turning direction
  #      (i.e. ~360° total) and eventually returns to near its original heading.
  #    - If it's actually ~720°, you may see it repeated.
  #    - We confirm it's within a short timespan (SPIN_MAX_SECONDS).
  #
  # 4. **Rounding**:
  #    - If we see a heading change ≥ ROUNDING_ANGLE, but it doesn't match
  #      the tack / jibe logic, we label it rounding.
  #
  # ### Memory & Performance
  #
  #  - **find_in_batches**: We read the DB in chunks of 100 or so.
  #  - **Sliding Window**: We keep only ~WINDOW_SECONDS worth of points in memory at once.
  #  - **Sign‐Flip and Stability Checks**: We only finalize a turn if we see
  #    multiple consecutive sign flips or stable headings.
  #
  # ### Configuration Constants
  #  - `WINDOW_SECONDS`: how long (in real time) to store headings in the rolling buffer.
  #  - `HEAD_TO_WIND_MARGIN` and `DEAD_DOWNWIND_MARGIN`: tolerances around the wind direction
  #    for upwind/downwind detection if wind_direction is present.
  #  - `MIN_ABS_CUMULATIVE`: The smallest heading change to count as a maneuver (≥30°).
  #  - `TACK_ANGLE`, `JIBE_ANGLE`, `ROUNDING_ANGLE`, `SPIN_ANGLE`:
  #    numeric thresholds if we can't or don't rely on wind direction.
  #  - `STABLE_DELTA_THRESHOLD`: small heading changes (<5°) are considered "stable."
  #  - `STABLE_CONSECUTIVE_PTS`: how many consecutive stable points required to finalize turn.
  #  - `REVERSE_FLIP_COUNT`: number of consecutive sign flips needed for a genuine direction reversal.
  #  - `SPIN_MAX_SECONDS`: if a ~360° spin took too long, we consider it not a penalty spin.
  #
  class ManeuverDetectionService
    # -----------------------------
    #       CONFIGURABLE CONSTANTS
    # -----------------------------
    WINDOW_SECONDS           = 15

    # For wind‐aware detection:
    HEAD_TO_WIND_MARGIN      = 45   # ±45° around wind_direction => "head to wind"
    DEAD_DOWNWIND_MARGIN     = 30   # ±30° around wind_direction + 180 => "dead downwind"

    # Numeric thresholds (fallback if wind is unknown or we can't confirm crossing):
    MIN_ABS_CUMULATIVE       = 30   # anything <30° => no maneuver
    TACK_ANGLE               = 70
    JIBE_ANGLE               = 30
    ROUNDING_ANGLE           = 120
    SPIN_ANGLE               = 315  # ~360°, might be a penalty spin

    STABLE_DELTA_THRESHOLD   = 5.0
    STABLE_CONSECUTIVE_PTS   = 3

    REVERSE_FLIP_COUNT       = 2
    SPIN_MAX_SECONDS         = 20

    ##
    # @param recording_id [Integer] The ID of the Recording to process
    # @param wind_direction [Numeric,nil] The approximate wind direction in degrees (0..359) if known
    #
    def initialize(recording_id, wind_direction: nil)
      @recording_id    = recording_id
      # If we have wind_direction, we can do more "tack vs jibe" logic
      @wind_direction  = wind_direction
    end

    ##
    # Main entry point: runs the detection, saving Maneuver records to the DB.
    #
    # If re‐running on the same recording, it clears out old maneuvers first.
    #
    def call
      rec = Recording.find_by(id: @recording_id)
      return unless rec

      rec.maneuvers.delete_all
      detect_maneuvers(rec)
    rescue => e
      ErrorNotifierService.notify(e, recording_id: @recording_id)
    end

    private

    ##
    # detect_maneuvers processes the boat's location data in small chunks:
    # - Maintains a "turn_points" array describing the current turn in progress
    # - Finalizes a turn once we see the boat become stable or actually reverse direction
    #
    # @param recording [Recording]
    #
    def detect_maneuvers(recording)
      turn_points   = []
      prev_heading  = nil
      current_sign  = 0
      stable_count  = 0
      flip_count    = 0

      turn_start_at = nil

      recording.recorded_locations
               .processed
               .not_simplified
               .chronological
               .find_in_batches(batch_size: 100) do |batch|
        batch.each do |loc|
          if turn_points.empty?
            turn_points << build_turn_point(loc, 0.0)
            prev_heading = loc.heading.to_f
            turn_start_at = loc.recorded_at
            next
          end

          # 1) Compute heading delta from the previous
          this_heading  = loc.heading.to_f
          delta         = signed_delta(prev_heading, this_heading)
          prev_heading  = this_heading

          # 2) Accumulate in turn_points
          cumulative = turn_points.last[:cumulative] + delta
          turn_points << build_turn_point(loc, cumulative)

          # 3) Trim old points older than (current_time - WINDOW_SECONDS)
          trim_old_points(turn_points, loc.recorded_at)

          # 4) Determine turning sign
          sign = delta <=> 0
          if sign != 0
            if current_sign == 0
              current_sign = sign
              flip_count   = 0
            elsif sign != current_sign
              flip_count  += 1
            else
              flip_count   = 0
            end
          end

          # 5) Stable or not?
          if delta.abs < STABLE_DELTA_THRESHOLD
            stable_count += 1
          else
            stable_count = 0
          end

          # 6) Finalize if sign reversed enough times or stable for a while
          if flip_count >= REVERSE_FLIP_COUNT || stable_count >= STABLE_CONSECUTIVE_PTS
            finalize_turn(turn_points, turn_start_at, loc.recorded_at, recording)
            turn_points    = [ turn_points.last ] # keep the last point as the start for the next
            stable_count   = 0
            flip_count     = 0
            current_sign   = 0
            turn_start_at  = loc.recorded_at
          end
        end
      end

      # End of data
      if turn_points.size >= 2
        rec = Recording.find(@recording_id)
        finalize_turn(turn_points, turn_start_at, turn_points.last[:loc].recorded_at, rec)
      end
    end

    ##
    # build_turn_point just wraps the location + cumulative heading
    #
    def build_turn_point(loc, cumulative)
      { loc: loc, cumulative: cumulative }
    end

    ##
    # Removes points from the front if older than current_time - WINDOW_SECONDS
    #
    def trim_old_points(points, current_time)
      cutoff = current_time - WINDOW_SECONDS
      points.shift while points.size > 1 && points.first[:loc].recorded_at < cutoff
    end

    ##
    # finalize_turn decides whether this turning arc is big enough to form a maneuver,
    # classifies it, and writes a Maneuver row if so.
    #
    def finalize_turn(points, turn_start_at, turn_end_at, recording)
      return if points.size < 2

      total_change = points.last[:cumulative] - points.first[:cumulative]
      net_abs      = total_change.abs
      return if net_abs < MIN_ABS_CUMULATIVE

      # If it's ~360°, confirm it's quick enough to be a penalty spin
      duration = turn_end_at - turn_start_at
      if net_abs >= SPIN_ANGLE && duration > SPIN_MAX_SECONDS
        # boat meandered too slowly => skip labeling as spin
        return
      end

      # "halfway" to store in the DB
      half_target = points.first[:cumulative] + (total_change / 2.0)
      half_idx    = find_halfway_index(points, half_target)
      half_point  = interpolate_halfway(points, half_idx, half_target)

      create_maneuver(recording, points, total_change, half_point)
    end

    ##
    # find_halfway_index returns the index in points where we cross half_target
    #
    def find_halfway_index(points, half_target)
      points.each_with_index do |pt, idx|
        return idx if half_target >= 0 && pt[:cumulative] >= half_target
        return idx if half_target <  0 && pt[:cumulative] <= half_target
      end
      points.size - 1
    end

    ##
    # interpolate_halfway does a basic linear interpolation if half_target lies
    # between two points' cumulative headings
    #
    def interpolate_halfway(points, idx, half_target)
      return build_interpolated(points[idx], half_target) if idx <= 0 || idx >= points.size

      p0 = points[idx - 1]
      p1 = points[idx]

      c0 = p0[:cumulative]
      c1 = p1[:cumulative]

      return build_interpolated(p1, half_target) if (c1 - c0).abs < 1e-5

      frac = (half_target - c0) / (c1 - c0)

      t0   = p0[:loc].recorded_at.to_f
      t1   = p1[:loc].recorded_at.to_f
      tmid = Time.at(t0 + frac * (t1 - t0))

      lat0 = p0[:loc].adjusted_latitude.to_f
      lat1 = p1[:loc].adjusted_latitude.to_f
      lon0 = p0[:loc].adjusted_longitude.to_f
      lon1 = p1[:loc].adjusted_longitude.to_f

      {
        loc: nil,
        occurred_at: tmid,
        lat: lerp(lat0, lat1, frac),
        lon: lerp(lon0, lon1, frac),
        cumulative: half_target
      }
    end

    ##
    # build_interpolated is a fallback if the halfway is basically at p1 or p0
    #
    def build_interpolated(point, half_target)
      {
        loc: point[:loc],
        occurred_at: point[:loc].recorded_at,
        lat: point[:loc].adjusted_latitude.to_f,
        lon: point[:loc].adjusted_longitude.to_f,
        cumulative: half_target
      }
    end

    ##
    # create_maneuver writes a Maneuver to DB with classification & confidence
    #
    def create_maneuver(recording, points, total_change, mid)
      mtype   = classify_maneuver(total_change, points)
      conf    = compute_confidence(points, total_change)

      lat, lon, occured =
        if mid[:loc].present?
          [
            mid[:loc].adjusted_latitude.to_f,
            mid[:loc].adjusted_longitude.to_f,
            mid[:loc].recorded_at
          ]
        else
          [ mid[:lat], mid[:lon], mid[:occurred_at] ]
        end

      Maneuver.create!(
        recording: recording,
        cumulative_heading_change: total_change.round(2),
        latitude:  lat.round(6),
        longitude: lon.round(6),
        occurred_at: occured,
        maneuver_type: mtype,
        confidence: conf
      )
    end

    ##
    # classify_maneuver attempts to infer tack, jibe, spin, rounding, etc.
    #
    # If @wind_direction is known, we try to see if the boat crossed "head to wind"
    # or "dead downwind" lines. Otherwise, we fallback to numeric angle thresholds.
    #
    def classify_maneuver(total_change, points)
      abs_change = total_change.abs

      # Check penalty spin first
      return "penalty_spin" if abs_change >= SPIN_ANGLE

      # If wind_direction is present, try to see if we "tacked" or "jibed" specifically:
      if @wind_direction
        if crossed_head_to_wind?(points) then return "tack" end
        if crossed_dead_downwind?(points) then return "jibe" end
      end

      # Fallback numeric approach:
      return "rounding"     if abs_change >= ROUNDING_ANGLE
      return "tack"         if abs_change >= TACK_ANGLE
      return "jibe"         if abs_change >= JIBE_ANGLE
      "unknown"
    end

    ##
    # compute_confidence is a naive approach: bigger arcs & more data => higher confidence
    #
    def compute_confidence(points, total_change)
      p_factor = [ points.size.to_f / 15.0, 1.0 ].min
      h_factor = [ total_change.abs / 180.0, 1.0 ].min
      [ p_factor + h_factor, 1.0 ].min.round(3)
    end

    ##
    # crossed_head_to_wind? checks if the boat was near (wind_direction ± HEAD_TO_WIND_MARGIN),
    # then ended up near (wind_direction ± HEAD_TO_WIND_MARGIN) on the other side of the wind
    #
    # This is a naive approach. You could sample the first few points & last few points
    # to see if we "crossed" from e.g. wind_direction- to wind_direction+.
    #
    def crossed_head_to_wind?(points)
      return false if @wind_direction.nil? || points.size < 2

      first_heading = points.first[:loc].heading.to_f
      last_heading  = points.last[:loc].heading.to_f

      # Are both first & last near wind_direction ± HEAD_TO_WIND_MARGIN,
      # but on opposite sides of the wind_direction?
      near_first = (first_heading - @wind_direction).abs <= HEAD_TO_WIND_MARGIN
      near_last  = (last_heading  - @wind_direction).abs <= HEAD_TO_WIND_MARGIN

      if near_first && near_last
        # Did we cross from negative to positive or vice versa relative to wind dir?
        before_sign = signed_delta(@wind_direction, first_heading) <=> 0
        after_sign  = signed_delta(@wind_direction, last_heading)  <=> 0
        return before_sign != 0 && after_sign != 0 && (before_sign != after_sign)
      end
      false
    end

    ##
    # crossed_dead_downwind? checks if the boat was near (wind_direction+180 ± DEAD_DOWNWIND_MARGIN),
    # then ended up near the other side
    #
    def crossed_dead_downwind?(points)
      return false if @wind_direction.nil? || points.size < 2

      ddw = (@wind_direction + 180) % 360
      first_heading = points.first[:loc].heading.to_f
      last_heading  = points.last[:loc].heading.to_f

      near_first = (signed_delta(ddw, first_heading)).abs <= DEAD_DOWNWIND_MARGIN
      near_last  = (signed_delta(ddw, last_heading)).abs  <= DEAD_DOWNWIND_MARGIN

      if near_first && near_last
        # Did we cross the line from negative to positive or vice versa?
        before_sign = signed_delta(ddw, first_heading) <=> 0
        after_sign  = signed_delta(ddw, last_heading)  <=> 0
        return before_sign != 0 && after_sign != 0 && (before_sign != after_sign)
      end
      false
    end

    ##
    # signed_delta returns heading difference in -180..180
    #
    def signed_delta(h1, h2)
      diff = (h2 - h1) % 360
      diff > 180 ? diff - 360 : diff
    end

    ##
    # lerp is a standard linear interpolation method
    #
    def lerp(a, b, fraction)
      a + (b - a) * fraction
    end
  end
end
