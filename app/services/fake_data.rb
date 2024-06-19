# class FakeData
#   START_LAT = 37.8091
#   START_LON = -122.4471
#   WIND_DIRECTION = 292.5 # WNW
#   LEG_DISTANCE_NM = 0.75 # Three-quarter nautical mile
#   TACKS = 6 # Number of tacks for upwind leg
#   JIBES = 2  # Number of jibes for downwind leg
#   BOAT_SPEED_KNOTS = 3 # Boat speed in knots
#   READ_INTERVAL_SECONDS = 5 # Time interval for coordinate readings

#   def generate
#     start_time = DateTime.now
#     tack_angle = 45 # Example added angle for tacking
#     jibe_angle = 135 # Example added angle for jibing

#     # Generate upwind leg
#     upwind_leg, upwind_end_time = generate_leg(START_LAT, START_LON, WIND_DIRECTION, LEG_DISTANCE_NM, TACKS, true, start_time, tack_angle)

#     # Generate downwind leg
#     downwind_leg, downwind_end_time = generate_leg(upwind_leg.last[:latitude], upwind_leg.last[:longitude], WIND_DIRECTION + 180, LEG_DISTANCE_NM, JIBES, false, upwind_end_time, jibe_angle)

#     # Combine upwind and downwind legs for the full race course
#     race_course = upwind_leg + downwind_leg

#     # Output the race course coordinates
#     race_course.each do |coord|
#       puts "Time: #{coord[:time].strftime('%Y-%m-%dT%H:%M:%S%z')}, Latitude: #{'%.6f' % coord[:latitude]}, Longitude: #{'%.6f' % coord[:longitude]}"
#     end
#   end

#   private

#   def bearing_to_coordinates(lat, lon, bearing, distance_nm)
#     # Earth's radius in nautical miles
#     earth_radius_nm = 3440.065
#     distance_rad = distance_nm / earth_radius_nm
#     bearing_rad = bearing * Math::PI / 180
#     lat_rad = lat * Math::PI / 180
#     lon_rad = lon * Math::PI / 180

#     new_lat_rad = Math.asin(Math.sin(lat_rad) * Math.cos(distance_rad) + Math.cos(lat_rad) * Math.sin(distance_rad) * Math.cos(bearing_rad))
#     new_lon_rad = lon_rad + Math.atan2(Math.sin(bearing_rad) * Math.sin(distance_rad) * Math.cos(lat_rad), Math.cos(distance_rad) - Math.sin(lat_rad) * Math.sin(new_lat_rad))
#     [new_lat_rad * 180 / Math::PI, new_lon_rad * 180 / Math::PI]
#   end

#   def generate_leg(start_lat, start_lon, wind_direction, leg_distance_nm, maneuvers, is_upwind, start_time, angle)
#     angle_adjustment = angle + rand(-5..5) # Randomizing the angle slightly for realism
#     effective_distance_nm = leg_distance_nm / Math.cos(angle_adjustment * Math::PI / 180)
#     steps = (effective_distance_nm / (BOAT_SPEED_KNOTS.to_f / 3600 * READ_INTERVAL_SECONDS)).ceil

#     coordinates = [{latitude: start_lat, longitude: start_lon, time: start_time}]
#     step_distance_nm = BOAT_SPEED_KNOTS.to_f * READ_INTERVAL_SECONDS / 3600

#     steps.times do
#       current_coord = coordinates.last
#       bearing_variation = rand(-2..2) # Randomize bearing for realism
#       bearing = wind_direction + ((is_upwind ? 1 : -1) * angle_adjustment) + bearing_variation

#       lat, lon = current_coord[:latitude], current_coord[:longitude]
#       new_lat, new_lon = bearing_to_coordinates(lat, lon, bearing, step_distance_nm)
#       next_time = current_coord[:time] + Rational(READ_INTERVAL_SECONDS, 86400)

#       coordinates << {latitude: new_lat, longitude: new_lon, time: next_time}
#     end

#     [coordinates, coordinates.last[:time]]
#   end
# end

# # FakeData.generate.each do |c|
# #   Recording.find(27).recorded_locations.create(latitude: c[:latitude], longitude: c[:longitude], accuracy: 3)
# # end
