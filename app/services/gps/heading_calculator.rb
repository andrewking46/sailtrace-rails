# frozen_string_literal: true

module Gps
  # HeadingCalculator calculates the initial bearing (heading) between two points
  # The heading represents the direction of travel from the start point to the end point
  module HeadingCalculator
    module_function

    # Calculates the heading between two points
    # @param start_point [Object] Starting point with adjusted_latitude and adjusted_longitude methods
    # @param end_point [Object] Ending point with adjusted_latitude and adjusted_longitude methods
    # @return [Float] Heading in degrees (0-360, where 0 is North, 90 is East, etc.)
    def calculate(start_point, end_point)
      lat1, lon1 = start_point.adjusted_latitude, start_point.adjusted_longitude
      lat2, lon2 = end_point.adjusted_latitude, end_point.adjusted_longitude

      # Convert latitude and longitude to radians
      lat1_rad = lat1 * Math::PI / 180
      lat2_rad = lat2 * Math::PI / 180
      lon_diff_rad = (lon2 - lon1) * Math::PI / 180

      # Calculate y and x components
      y = Math.sin(lon_diff_rad) * Math.cos(lat2_rad)
      x = Math.cos(lat1_rad) * Math.sin(lat2_rad) -
          Math.sin(lat1_rad) * Math.cos(lat2_rad) * Math.cos(lon_diff_rad)

      # Calculate heading in radians and convert to degrees
      heading_rad = Math.atan2(y, x)
      heading_deg = (heading_rad * 180 / Math::PI + 360) % 360

      heading_deg
    end
  end
end
