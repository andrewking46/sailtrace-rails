# frozen_string_literal: true

module Recordings
  ##
  # ManeuverDetectionService detects key sailing maneuvers (tacks, jibes,
  # roundings, penalty spins, etc.) from raw heading data. It also now takes
  # into account an approximate wind direction if available, with some leeway
  # to account for shifting or imperfect readings.
  #
  # Usage:
  #   Recordings::ManeuverDetectionService.new(
  #     recording_id: some_id,
  #     wind_direction_degrees: some_value_or_nil
  #   ).call
  #
  class ManeuverDetectionService
    # --------------------------------
    # CONFIGURABLE CONSTANTS
    # --------------------------------

    # Window of time (seconds) to keep headings in our rolling buffer:
    WINDOW_SECONDS           = 25

    # Margins used to detect crossing the wind or dead downwind (with extra leeway):
    HEAD_TO_WIND_MARGIN      = 55
    DEAD_DOWNWIND_MARGIN     = 30

    # Numeric thresholds if we can't use wind direction or as a fallback:
    MIN_ABS_CUMULATIVE       = 30   # ignore small turns < N°
    TACK_ANGLE               = 70
    JIBE_ANGLE               = 30
    ROUNDING_ANGLE           = 120
    SPIN_ANGLE               = 315  # ~360°, might be a penalty spin

    # Stability / sign-flip thresholds:
    STABLE_DELTA_THRESHOLD   = 10.0  # headings changing <N° are "stable"
    STABLE_CONSECUTIVE_PTS   = 3    # need 3 stable points
    REVERSE_FLIP_COUNT       = 2    # consecutive sign flips => turn is done

    # Timing constraints for penalty spin:
    SPIN_MAX_SECONDS         = 20   # ~360° must happen quickly => penalty spin
    SPIN_MIN_SECONDS         = 8    # ~360 must not happen too quickly

    ##
    # Constructor
    # @param recording_id [Integer] The ID of the Recording we want to process
    # @param wind_direction_degrees [Float, nil] The approximate wind direction in degrees (0..359) if known
    #
    def initialize(recording_id:, wind_direction_degrees: nil)
      @recording_id    = recording_id
      @wind_direction  = wind_direction_degrees
    end

    ##
    # Runs detection and stores Maneuver records in DB. If we have no known
    # wind direction, we return early (per user request). If you prefer to
    # fallback to numeric thresholds, just remove the 'return' line.
    #
    def call
      # If we want to skip detection entirely without wind info, do so here:
      return unless @wind_direction.is_a? Integer

      rec = Recording.find_by(id: @recording_id)
      return unless rec

      # Clear out old maneuvers if re-running
      rec.maneuvers.delete_all

      # Main detection method
      detect_maneuvers(rec)
    rescue => e
      ErrorNotifierService.notify(e, recording_id: @recording_id)
    end

    private

    ##
    # detect_maneuvers processes the boat's location data in small chunks.
    #
    # 1) We maintain a "turn_points" array describing the current turn in progress.
    # 2) Once stable or we reverse direction, we finalize the turn with finalize_turn.
    # 3) Each turn may become a tack, jibe, rounding, or penalty spin, depending on
    #    the heading arcs and timing.
    #
    # Because wind direction is known in this version, we rely on it heavily
    # for classification. We still keep track of numeric arcs as a fallback
    # if the crossing logic is inconclusive.
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
          # If this is the first location in a turn, initialize everything
          if turn_points.empty?
            turn_points   << build_turn_point(loc, 0.0)
            prev_heading   = loc.heading.to_f
            turn_start_at  = loc.recorded_at
            next
          end

          # 1) Compute delta from the previous heading
          this_heading  = loc.heading.to_f
          delta         = signed_delta(prev_heading, this_heading)
          prev_heading  = this_heading

          # 2) Accumulate in turn_points
          new_cumulative = turn_points.last[:cumulative] + delta
          turn_points << build_turn_point(loc, new_cumulative)

          # 3) Trim older points beyond our rolling window
          trim_old_points(turn_points, loc.recorded_at)

          # 4) Determine turning sign (negative vs. positive)
          sign = delta <=> 0
          if sign != 0
            if current_sign == 0
              # first sign in this turn
              current_sign = sign
              flip_count   = 0
            elsif sign != current_sign
              # sign has flipped
              flip_count += 1
            else
              # same sign as before
              flip_count = 0
            end
          end

          # 5) Check if heading is stable
          if delta.abs < STABLE_DELTA_THRESHOLD
            stable_count += 1
          else
            stable_count = 0
          end

          # 6) If we see enough sign flips or stable points => finalize the turn
          if flip_count >= REVERSE_FLIP_COUNT || stable_count >= STABLE_CONSECUTIVE_PTS
            finalize_turn(turn_points, turn_start_at, loc.recorded_at, recording)

            # Keep the last point for continuity
            turn_points   = [ turn_points.last ]
            stable_count  = 0
            flip_count    = 0
            current_sign  = 0
            turn_start_at = loc.recorded_at
          end
        end
      end

      # After all points are processed, see if there's a partial turn left over
      if turn_points.size >= 2
        rec = Recording.find(@recording_id)
        finalize_turn(turn_points, turn_start_at, turn_points.last[:loc].recorded_at, rec)
      end
    end

    ##
    # build_turn_point: store location + a running (cumulative) heading change
    #
    def build_turn_point(loc, cumulative)
      { loc: loc, cumulative: cumulative }
    end

    ##
    # trim_old_points: remove the oldest points if they are beyond the time window
    #
    def trim_old_points(points, current_time)
      cutoff = current_time - WINDOW_SECONDS
      points.shift while points.size > 1 && points.first[:loc].recorded_at < cutoff
    end

    ##
    # finalize_turn: checks if this arc is big enough, classifies it, writes Maneuver if valid.
    #
    def finalize_turn(points, turn_start_at, turn_end_at, recording)
      return if points.size < 2

      total_change = points.last[:cumulative] - points.first[:cumulative]
      net_abs      = total_change.abs
      return if net_abs < MIN_ABS_CUMULATIVE

      # If it's ~360° but took too long => no penalty spin
      duration = turn_end_at - turn_start_at
      if net_abs >= SPIN_ANGLE && duration < SPIN_MIN_SECONDS && duration > SPIN_MAX_SECONDS
        return
      end

      # Interpolate the halfway point for storing lat/lon
      half_target = points.first[:cumulative] + (total_change / 2.0)
      half_idx    = find_halfway_index(points, half_target)
      half_point  = interpolate_halfway(points, half_idx, half_target)

      create_maneuver(recording, points, total_change, half_point, duration)
    end

    ##
    # find_halfway_index: find index in 'points' where we cross half_target
    #
    def find_halfway_index(points, half_target)
      points.each_with_index do |pt, idx|
        return idx if half_target >= 0 && pt[:cumulative] >= half_target
        return idx if half_target <  0 && pt[:cumulative] <= half_target
      end
      points.size - 1
    end

    ##
    # interpolate_halfway: linear interpolation if needed
    #
    def interpolate_halfway(points, idx, half_target)
      return build_interpolated(points[idx], half_target) if idx <= 0 || idx >= points.size

      p0 = points[idx - 1]
      p1 = points[idx]
      c0 = p0[:cumulative]
      c1 = p1[:cumulative]

      # If c1 ≈ c0, we can't interpolate meaningfully
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
    # build_interpolated: fallback if the halfway target is at an existing point
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
    # create_maneuver: classify the turn, compute a confidence, and insert Maneuver in DB
    #
    def create_maneuver(recording, points, total_change, mid, duration)
      mtype = classify_maneuver(total_change, points, duration)
      conf  = compute_confidence(points, total_change)

      # If the halfway location is an actual point, we can just read from it
      lat, lon, occurred =
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
        recording:               recording,
        cumulative_heading_change: total_change.round(2),
        latitude:                lat.round(6),
        longitude:               lon.round(6),
        occurred_at:             occurred,
        maneuver_type:           mtype,
        confidence:              conf
      )
    end

    ##
    # classify_maneuver: tries to classify tacks, jibes, penalty spins, roundings, etc.
    #
    # We have an approximate wind direction, so we:
    # 1) Check for penalty spin: (a) if total_change ~360° in short time, or (b) if we
    #    detect a tack & jibe in quick succession in the same rotational direction.
    # 2) If not spin, see if we actually "crossed" head-to-wind or dead-downwind.
    # 3) If that fails, fallback to numeric thresholds.
    #
    def classify_maneuver(total_change, points, duration)
      abs_change = total_change.abs

      # 1) Check penalty spin first: ~360° quickly
      if abs_change >= SPIN_ANGLE && duration >= SPIN_MIN_SECONDS && duration <= SPIN_MAX_SECONDS
        return "penalty_spin"
      end

      # 2) Tacks or Jibes using wind direction crossing
      if crossed_head_to_wind?(points)
        return "tack"
      elsif crossed_dead_downwind?(points)
        return "jibe"
      end

      # 3) If crossing logic fails, fallback to numeric angles:
      return "rounding" if abs_change >= ROUNDING_ANGLE
      return "tack"     if abs_change >= TACK_ANGLE
      return "jibe"     if abs_change >= JIBE_ANGLE

      "unknown"
    end

    ##
    # compute_confidence: naive approach that considers:
    # - number of points
    # - absolute heading change
    #
    def compute_confidence(points, total_change)
      p_factor = [ points.size.to_f / 15.0, 1.0 ].min
      h_factor = [ total_change.abs / 180.0, 1.0 ].min
      (p_factor + h_factor).clamp(0.0, 1.0).round(3)
    end

    ##
    # crossed_head_to_wind?: checks if boat started near wind_direction ± HEAD_TO_WIND_MARGIN,
    # then ended near that range but on the opposite side. This is naive but effective enough
    # for basic classification. Slightly expanded margin from the original version.
    #
    def crossed_head_to_wind?(points)
      return false if @wind_direction.nil? || points.size < 2

      first_heading = points.first[:loc].heading.to_f
      last_heading  = points.last[:loc].heading.to_f

      near_first = (first_heading - @wind_direction).abs <= HEAD_TO_WIND_MARGIN
      near_last  = (last_heading  - @wind_direction).abs <= HEAD_TO_WIND_MARGIN

      # Must have started near wind_dir, ended near wind_dir, and cross the line in between
      if near_first && near_last
        before_sign = signed_delta(@wind_direction, first_heading) <=> 0
        after_sign  = signed_delta(@wind_direction, last_heading)  <=> 0
        return (before_sign != 0) && (after_sign != 0) && (before_sign != after_sign)
      end
      false
    end

    ##
    # crossed_dead_downwind?: checks if boat started near wind_direction+180 ± DEAD_DOWNWIND_MARGIN,
    # then ended near that range but on the other side.
    #
    def crossed_dead_downwind?(points)
      return false if @wind_direction.nil? || points.size < 2

      ddw = (@wind_direction + 180) % 360
      first_heading = points.first[:loc].heading.to_f
      last_heading  = points.last[:loc].heading.to_f

      near_first = signed_delta(ddw, first_heading).abs <= DEAD_DOWNWIND_MARGIN
      near_last  = signed_delta(ddw, last_heading).abs  <= DEAD_DOWNWIND_MARGIN

      if near_first && near_last
        before_sign = signed_delta(ddw, first_heading) <=> 0
        after_sign  = signed_delta(ddw, last_heading)  <=> 0
        return (before_sign != 0) && (after_sign != 0) && (before_sign != after_sign)
      end
      false
    end

    ##
    # signed_delta: returns difference (h2 - h1) in range -180..180, perfect for headings
    #
    def signed_delta(h1, h2)
      diff = (h2 - h1) % 360
      diff > 180 ? diff - 360 : diff
    end

    ##
    # lerp: standard linear interpolation
    #
    def lerp(a, b, fraction)
      a + (b - a) * fraction
    end
  end
end
