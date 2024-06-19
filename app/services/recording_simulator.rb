# class RecordingSimulator
#   attr_reader :path, :wind_direction, :boat_position, :target_mark, :downwind_return

#   # Constants for simulation
#   INITIAL_WIND_DIRECTION = 0 # Assuming wind from North at start, in degrees
#   WINDWARD_MARK_DISTANCE_NM = 0.75 # Distance to windward mark in nautical miles
#   START_POS = { lat: 37.8091, lon: -122.4471 }
#   BOAT_SPEED = 5 # Knots, optimal speed for simplicity

#   def initialize
#     @wind_direction = INITIAL_WIND_DIRECTION
#     @boat_position = START_POS.dup
#     @target_mark = calculate_target_mark(INITIAL_WIND_DIRECTION)
#     @downwind_return = false
#     @path = [@boat_position.dup]
#     @boat_heading = (@wind_direction - 45) % 360
#   end

#   def simulate_recording
#     while !race_completed?
#       make_sailing_decision
#       log_current_position
#     end
#   end

#   private

#   def calculate_target_mark(initial_wind_direction)
#     # Assuming wind direction in degrees from North, converting to radians for calculation
#     wind_rad = initial_wind_direction * Math::PI / 180

#     # Earth's radius in nautical miles
#     earth_radius_nm = 3440.065

#     # Convert the direct distance to the windward mark into radians
#     distance_rad = WINDWARD_MARK_DISTANCE_NM.to_f / earth_radius_nm

#     # Starting position in radians
#     start_lat_rad = START_POS[:lat] * Math::PI / 180
#     start_lon_rad = START_POS[:lon] * Math::PI / 180

#     # Calculate the target mark's latitude
#     target_lat_rad = Math.asin(Math.sin(start_lat_rad) * Math.cos(distance_rad) +
#                                Math.cos(start_lat_rad) * Math.sin(distance_rad) * Math.cos(wind_rad))

#     # Calculate the target mark's longitude
#     target_lon_rad = start_lon_rad + Math.atan2(Math.sin(wind_rad) * Math.sin(distance_rad) * Math.cos(start_lat_rad),
#                                                 Math.cos(distance_rad) - Math.sin(start_lat_rad) * Math.sin(target_lat_rad))

#     # Convert back to degrees
#     target_lat = target_lat_rad * 180 / Math::PI
#     target_lon = target_lon_rad * 180 / Math::PI

#     { lat: target_lat, lon: target_lon }
#   end

#   def make_sailing_decision
#     # Calculate the target bearing depending on the current leg of the race
#     target = @downwind_return ? START_POS : @target_mark
#     target_bearing = calculate_bearing(@boat_position, target)

#     # Determine the optimal tacking or jibing angle based on the wind direction
#     optimal_tack_jibe_angle = calculate_optimal_tack_jibe_angle(@wind_direction, target_bearing)

#     @boat_heading = optimal_tack_jibe_angle

#     # Check if it's time to switch from upwind to downwind or if the race is completed
#     if nearing_target? && !@downwind_return
#       @downwind_return = true
#       adjust_wind_for_downwind
#     elsif nearing_target? && @downwind_return
#       # Race completion logic if needed
#     end

#     update_boat_position
#     check_for_wind_shift
#   end

#   def calculate_optimal_tack_jibe_angle(wind_direction, target_bearing)
#     # Simplified logic to choose the best side to tack or jibe based on the wind direction and target bearing
#     wind_relative_angle = (360 + target_bearing - wind_direction) % 360
#     if @downwind_return
#       # Choose jibing angle for downwind
#       return wind_relative_angle > 180 ? wind_direction - 135 : wind_direction + 135
#     else
#       # Choose tacking angle for upwind
#       return wind_relative_angle > 180 ? wind_direction - 45 : wind_direction + 45
#     end
#   end

#   def nearing_target?
#     distance_to_target = calculate_distance(@boat_position, @target_mark)
#     distance_to_target <= 0.01 # Near enough to the target mark to round it
#   end

#   def adjust_wind_for_downwind
#     @wind_direction = (@wind_direction + 180) % 360 # Reverse wind direction for simulation
#   end

#   def adjust_course_for_optimal_vmg
#     # Determine whether the boat is upwind or downwind relative to the target
#     target_bearing = calculate_bearing(@boat_position, @downwind_return ? START_POS : @target_mark)
#     wind_relative_angle = (360 + target_bearing - @wind_direction) % 360

#     # Optimal tacking or jibing angles for most sailboats range between 40-45 degrees upwind and 130-135 degrees downwind
#     optimal_angle = @downwind_return ? 135 : 45

#     # Decide whether to tack/jibe based on the wind's relative angle to the target bearing
#     # If the wind is on the port side, adjust the course to the optimal angle off the wind direction
#     if wind_relative_angle.between?(0, 180)
#       @boat_heading = (@wind_direction + optimal_angle) % 360
#     else
#       @boat_heading = (@wind_direction - optimal_angle) % 360
#     end

#     # Adjust the heading to steer closer to the target if directly sailing towards it is possible
#     direct_course_possible = @downwind_return ? wind_relative_angle.between?(90, 270) : !wind_relative_angle.between?(90, 270)
#     @boat_heading = target_bearing if direct_course_possible
#   end

#   def update_boat_position
#     # Calculate VMG towards the target mark or starting line, depending on the leg
#     target = @downwind_return ? START_POS : @target_mark
#     target_bearing = calculate_bearing(@boat_position, target)
#     vmg = calculate_vmg(BOAT_SPEED, @wind_direction, @boat_heading, target_bearing)

#     # Convert VMG (in knots) to nautical miles per second for calculation
#     vmg_nmps = vmg / 3600.0

#     # Calculate the displacement in latitude and longitude
#     displacement_lat = vmg_nmps * Math.cos(@boat_heading * Math::PI / 180) * 3600
#     displacement_lon = vmg_nmps * Math.sin(@boat_heading * Math::PI / 180) * 3600 / Math.cos(@boat_position[:lat] * Math::PI / 180)

#     # Update the boat's position
#     @boat_position[:lat] += displacement_lat
#     @boat_position[:lon] += displacement_lon
#   end

#   def calculate_speed_from_polars(wind_direction, boat_heading)
#     # Placeholder: Implement logic to determine boat speed based on polar diagrams,
#     # which require wind speed and the true wind angle (TWA).
#     # This example returns a constant speed for simplicity.
#     BOAT_SPEED
#   end

#   def calculate_vmg(boat_speed, wind_direction, boat_heading, target_bearing)
#     # Calculate the angle between the boat's heading and the target
#     angle_to_target = (360 + boat_heading - target_bearing) % 360
#     angle_to_target_rad = angle_to_target * Math::PI / 180

#     # VMG is the component of the boat's speed in the direction of the target
#     vmg = boat_speed * Math.cos(angle_to_target_rad)
#     vmg
#   end

#   def check_for_wind_shift
#     # Realistically, wind shifts; this implementation periodically adjusts wind direction slightly.
#     @wind_direction = (@wind_direction + rand(-5..5)) % 360
#   end

#   def calculate_bearing(start_pos, target_pos)
#     start_lat_rad, start_lon_rad = start_pos.values.map { |deg| deg * Math::PI / 180 }
#     target_lat_rad, target_lon_rad = target_pos.values.map { |deg| deg * Math::PI / 180 }

#     dlon = target_lon_rad - start_lon_rad
#     x = Math.cos(target_lat_rad) * Math.sin(dlon)
#     y = Math.cos(start_lat_rad) * Math.sin(target_lat_rad) - Math.sin(start_lat_rad) * Math.cos(target_lat_rad) * Math.cos(dlon)

#     bearing_rad = Math.atan2(x, y)
#     (bearing_rad * 180 / Math::PI + 360) % 360
#   end

#   def calculate_distance(pos1, pos2)
#     rad_per_deg = Math::PI / 180
#     rkm = 6371 # Earth's radius in kilometers
#     rm = rkm * 0.539957 # Radius in nautical miles

#     dlat_rad = (pos2[:lat] - pos1[:lat]) * rad_per_deg
#     dlon_rad = (pos2[:lon] - pos1[:lon]) * rad_per_deg

#     lat1_rad = pos1[:lat] * rad_per_deg
#     lat2_rad = pos2[:lat] * rad_per_deg

#     a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2
#     c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

#     rm * c
#   end

#   def log_current_position
#     @path << @boat_position.dup
#   end

#   def race_completed?
#     @path.length > 1000
#     # @downwind_return && calculate_distance(@boat_position, START_POS) < 0.01
#   end
# end

# # # Initialize and run the simulation
# # simulator = RecordingSimulator.new
# # simulator.simulate_recording
