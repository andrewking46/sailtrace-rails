# class RecordingAnalysis
#   MIN_SEGMENT_DURATION = 5 # Minimum number of readings to consider a consistent segment
#   TACK_JIBE_THRESHOLD = 45 # Minimum bearing change to consider a tack or jibe
#   UPWIND_ANGLE_THRESHOLD = 90 # Angle difference for upwind segments

#   attr_reader :coordinates

#   def initialize(recording_id)
#     recording = Recording.find_by(id: recording_id)
#     @coordinates = coordinates
#     @segments = []
#     @maneuvers = []
#     @wind_direction = nil
#   end

#   def analyze_sailing
#     identify_segments
#     identify_maneuvers
#     estimate_wind_direction
#     classify_segments
#     @segments
#   end

#   private

#   def identify_segments
#     current_segment = [bearing(@coordinates.first)]
#     @coordinates.each_cons(2) do |coord1, coord2|
#       bearing = bearing(coord1, coord2)
#       if (bearing - current_segment.last).abs < TACK_JIBE_THRESHOLD
#         current_segment << bearing
#       else
#         @segments << current_segment if current_segment.length >= MIN_SEGMENT_DURATION
#         current_segment = [bearing]
#       end
#     end
#     @segments << current_segment if current_segment.length >= MIN_SEGMENT_DURATION # Add the last segment
#   end

#   def identify_maneuvers
#     @segments.each_cons(2) do |seg1, seg2|
#       angle_change = (seg2.first - seg1.last).abs
#       if angle_change >= TACK_JIBE_THRESHOLD
#         @maneuvers << { type: maneuver_type(angle_change), change: angle_change }
#       end
#     end
#   end

#   # Estimate wind direction from the bearings of the sailing segments
#   def estimate_wind_direction
#     perpendicular_segments = @segments.each_cons(2).select do |seg1, seg2|
#       angle_change = (seg2.first - seg1.last).abs
#       angle_change.between?(UPWIND_ANGLE_THRESHOLD - TACK_JIBE_THRESHOLD, UPWIND_ANGLE_THRESHOLD + TACK_JIBE_THRESHOLD)
#     end

#     if perpendicular_segments.any?
#       wind_bearings = perpendicular_segments.map do |seg1, seg2|
#         [(seg1.last + 90) % 360, (seg2.first + 90) % 360]
#       end.flatten

#       @wind_direction = wind_bearings.sum / wind_bearings.size
#     end

#     @wind_direction.round(2) if @wind_direction
#   end

#   # Classify each segment with its point of sail and tack based on the estimated wind direction
#   def classify_segments
#     return unless @wind_direction

#     @segments.map! do |segment|
#       avg_bearing = segment.sum / segment.size
#       point_of_sail = classify_point_of_sail(avg_bearing)
#       { average_bearing: avg_bearing.round(2), point_of_sail: point_of_sail, tack: classify_tack(avg_bearing) }
#     end
#   end

#   def classify_point_of_sail(bearing)
#     upwind_angle_range = (@wind_direction - 45)..(@wind_direction + 45)
#     downwind_angle_range = ((@wind_direction + 135) % 360)..((@wind_direction + 225) % 360)

#     if upwind_angle_range.cover?(bearing % 360)
#       'upwind'
#     elsif downwind_angle_range.cover?(bearing % 360)
#       'downwind'
#     else
#       'reach'
#     end
#   end

#   def classify_tack(bearing)
#     starboard_tack_range = (@wind_direction - 90)..(@wind_direction)
#     port_tack_range = (@wind_direction)..(@wind_direction + 90)

#     if starboard_tack_range.cover?(bearing % 360)
#       'starboard'
#     elsif port_tack_range.cover?(bearing % 360)
#       'port'
#     else
#       'unclear'
#     end
#   end

#   def bearing(coord1, coord2)
#     lat1_rad = to_radians(coord1[0])
#     lat2_rad = to_radians(coord2[0])
#     lon_diff_rad = to_radians(coord2[1] - coord1[1])

#     y = Math.sin(lon_diff_rad) * Math.cos(lat2_rad)
#     x = Math.cos(lat1_rad) * Math.sin(lat2_rad) - Math.sin(lat1_rad) * Math.cos(lat2_rad) * Math.cos(lon_diff_rad)
#     bearing = (to_degrees(Math.atan2(y, x)) + 360) % 360
#     bearing.round(2)
#   end

#   def maneuver_type(angle_change)
#     case angle_change
#     when 0..TACK_JIBE_THRESHOLD then 'minor_change'
#     when TACK_JIBE_THRESHOLD..UPWIND_ANGLE_THRESHOLD then 'tack'
#     when UPWIND_ANGLE_THRESHOLD..180 then 'jibe'
#     else 'major_change'
#     end
#   end

#   def to_radians(degrees)
#     degrees * Math::PI / 180
#   end

#   def to_degrees(radians)
#     radians * 180 / Math::PI
#   end
# end


# # bearing: Calculates the bearing between two latitude/longitude pairs using the Haversine formula.
# # estimate_wind_direction: Estimates the wind direction by finding segments that are approximately perpendicular to each other and inferring the wind direction as the average of their bearings.
# # classify_segments: Assigns a point of sail (upwind, downwind, reach) and tack (starboard, port) to each segment based on the estimated wind direction.
# # classify_point_of_sail: Determines the point of sail for a given bearing.
# # classify_tack: Determines the tack for a given bearing.
