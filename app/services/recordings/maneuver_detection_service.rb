# app/services/recordings/maneuver_detection_service.rb
# frozen_string_literal: true

# This service scans through a Recording's RecordedLocations to detect maneuvers based on
# the *cumulative* heading change in a sliding window of time.
#
# For example:
#  - If a boat does a penalty spin in 15 seconds, the net heading change might be 0
#    (ends on the same heading it started), but the *cumulative* is 360 => a spin.
#  - If a boat does random wobbles that add up to zero, the cumulative change will
#    fluctuate but eventually end near zero => no maneuver.
#
# Each identified maneuver is stored in the `maneuvers` table with:
#   - cumulative_heading_change: e.g. +360 or -180
#   - latitude/longitude: the point in time where half of that change was completed
#   - occurred_at: the timestamp of that point
#   - maneuver_type: "tack", "jibe", "penalty_spin", "rounding", etc.
#   - confidence: for possible future weighting or filtering
#
# Implementation details:
#   - We process the boat track in ascending recorded_at order.
#   - Keep a small time-based window of points (up to 15s).
#   - Keep track of consecutive heading deltas for each pair of adjacent points in the window.
#   - If the absolute cumulative sum crosses a threshold, we record a maneuver,
#     locate the "halfway" point to store lat/lon, remove that portion from the window.
#
module Recordings
  class ManeuverDetectionService
    WINDOW_SECONDS = 10
    MIN_ABS_CUMULATIVE = 45 # e.g. 60 degrees to consider an actual maneuver

    def initialize(recording_id)
      @recording = Recording.find(recording_id)
    end

    def call
      return unless @recording

      # If re-running, wipe old maneuvers
      @recording.maneuvers.delete_all

      detect_maneuvers
    rescue => e
      ErrorNotifierService.notify(e, recording_id: @recording&.id)
    end

    private

    # We'll store a small structure for each location in the current window:
    #  { loc: <RecordedLocation>, cumulative: <Float> }
    # "cumulative" is the cumulative heading change from the first point in the window to that point.
    def detect_maneuvers
      buffer = [] # array of {loc: <RecordedLocation>, cumulative: Float}
      prev_heading = nil

      @recording.recorded_locations
                .processed
                .not_simplified
                .chronological
                .find_in_batches(batch_size: 100) do |batch|
        batch.each do |loc|
          if buffer.empty?
            # If empty, this is the start of a new window
            buffer << { loc: loc, cumulative: 0.0 }
            prev_heading = loc.heading.to_f
            next
          end

          # 1) Calculate incremental heading delta from prev_heading to current
          incremental = signed_heading_delta(prev_heading, loc.heading.to_f)

          # 2) The new "cumulative" = last cumulative + incremental
          last_cumulative = buffer.last[:cumulative]
          new_cumulative = last_cumulative + incremental

          # 3) Append to the buffer
          buffer << { loc: loc, cumulative: new_cumulative }

          # 4) Trim old data outside the WINDOW_SECONDS threshold
          trim_old_points(buffer, loc.recorded_at)

          # 5) Check if we cross the threshold
          check_and_extract_maneuver(buffer)

          prev_heading = loc.heading.to_f
        end
      end

      # End of all data. If there's a partial leftover buffer, we do one last check:
      check_and_extract_maneuver(buffer)
    end

    # Remove leading points from buffer if they're older than current_time - WINDOW_SECONDS
    def trim_old_points(buffer, current_time)
      cutoff = current_time - WINDOW_SECONDS
      while buffer.size > 1 && buffer.first[:loc].recorded_at < cutoff
        buffer.shift
      end
    end

    # Evaluate if the absolute cumulative heading change (from first to last in buffer)
    # is above threshold. If so, we create a Maneuver record and remove that portion from buffer.
    def check_and_extract_maneuver(buffer)
      return if buffer.size < 2

      total_change = buffer.last[:cumulative] - buffer.first[:cumulative]
      if total_change.abs >= MIN_ABS_CUMULATIVE
        # We have a maneuver; let's find "halfway" point in cumulative heading
        half_target = buffer.first[:cumulative] + (total_change / 2.0)

        # 1) find the point in buffer that crosses half_target
        #    We'll do a simple linear interpolation if needed.
        half_index = find_halfway_index(buffer, half_target)
        half_entry = interpolate_halfway_position(buffer, half_index, half_target)

        # 2) Create the maneuver
        create_maneuver(buffer, total_change, half_entry)

        # 3) Remove up to that half_index from the buffer to avoid double-counting
        #    We'll keep points after that because a new maneuver could start.
        buffer.slice!(0..half_index)
      end
    end

    # Locates the index in the buffer that crosses half_target in cumulative heading
    def find_halfway_index(buffer, half_target)
      buffer.each_with_index do |entry, idx|
        return idx if entry[:cumulative] >= half_target && half_target >= 0
        return idx if entry[:cumulative] <= half_target && half_target < 0
      end
      buffer.size - 1
    end

    # Interpolate lat/lon if the half_target lies between two points
    def interpolate_halfway_position(buffer, index, half_target)
      return buffer[index] if index == 0 || index >= buffer.size

      prev_entry = buffer[index - 1]
      current_entry = buffer[index]

      prev_cum = prev_entry[:cumulative]
      curr_cum = current_entry[:cumulative]
      # If they are the same, just pick current
      return current_entry if (curr_cum - prev_cum).abs < 1e-5

      # Linear fraction
      frac = (half_target - prev_cum) / (curr_cum - prev_cum)

      # Interpolate time
      prev_time = prev_entry[:loc].recorded_at.to_f
      curr_time = current_entry[:loc].recorded_at.to_f
      occurred_at = Time.at(prev_time + frac * (curr_time - prev_time))

      # Interpolate lat/lon (simple linear interpolation)
      lat = lerp(prev_entry[:loc].adjusted_latitude.to_f, current_entry[:loc].adjusted_latitude.to_f, frac)
      lon = lerp(prev_entry[:loc].adjusted_longitude.to_f, current_entry[:loc].adjusted_longitude.to_f, frac)

      {
        loc: nil, # we made an interpolated point, not an actual location
        cumulative: half_target,
        occurred_at: occurred_at,
        lat: lat,
        lon: lon
      }
    end

    def create_maneuver(buffer, total_change, half_entry)
      maneuver_type = classify_maneuver(total_change)
      conf          = compute_confidence(buffer, total_change)

      # If half_entry[:loc] is nil => we used interpolation
      # Otherwise we can just read from half_entry[:loc]
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
        recording: @recording,
        cumulative_heading_change: total_change.round(2),
        latitude:  lat.round(6),
        longitude: lon.round(6),
        occurred_at: t,
        maneuver_type: maneuver_type,
        confidence: conf
      )
    end

    # Example classification: 360 => penalty_spin, 140 => rounding, ~80 => tack/jibe
    def classify_maneuver(total_change)
      abs = total_change.abs
      return "penalty_spin" if abs >= 315
      return "rounding"     if abs >= 120
      return "tack"         if abs >= 70
      return "jibe"         if abs >= 30
      "unknown"
    end

    def compute_confidence(buffer, total_change)
      # A naive approach: more points + bigger heading => higher confidence
      # E.g.  (# points / 10) + (abs(total_change)/180)
      # clamp from 0..1
      points_factor = [ buffer.size.to_f / 10.0, 1.0 ].min
      heading_factor = [ total_change.abs / 180.0, 1.0 ].min
      raw_conf = points_factor + heading_factor
      [ raw_conf, 1.0 ].min.round(3)
    end

    def signed_heading_delta(h1, h2)
      # We want a delta in -180..+180
      diff = (h2 - h1) % 360
      diff > 180 ? diff - 360 : diff
    end

    def lerp(a, b, fraction)
      a + (b - a) * fraction
    end
  end
end
