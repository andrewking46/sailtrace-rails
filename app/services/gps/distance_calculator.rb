# frozen_string_literal: true

module Gps
  # DistanceCalculator calculates the distance between two geographical points
  # using the Haversine formula, which accounts for the Earth's curvature
  class DistanceCalculator
    EARTH_RADIUS_KM = 6371.0 # Earth's mean radius in kilometers
    RAD_PER_DEG = Math::PI / 180.0 # Conversion factor from degrees to radians

    class << self
      # Calculates the distance between two points on Earth
      # @param lat1 [Float] Latitude of the first point in degrees
      # @param lon1 [Float] Longitude of the first point in degrees
      # @param lat2 [Float] Latitude of the second point in degrees
      # @param lon2 [Float] Longitude of the second point in degrees
      # @return [Float] Distance between the points in meters, rounded to 2 decimal places
      def distance_in_meters(lat1, lon1, lat2, lon2)
        return 0.0 unless valid_coordinates?(lat1, lon1, lat2, lon2)

        dlat = (lat2 - lat1) * RAD_PER_DEG
        dlon = (lon2 - lon1) * RAD_PER_DEG

        a = Math.sin(dlat / 2)**2 +
            Math.cos(lat1 * RAD_PER_DEG) *
            Math.cos(lat2 * RAD_PER_DEG) *
            Math.sin(dlon / 2)**2
        c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

        (EARTH_RADIUS_KM * c * 1000).round(2)
      end

      private

      # Validates that all coordinate values are numeric and finite
      # @return [Boolean] True if all coordinates are valid, false otherwise
      def valid_coordinates?(*values)
        values.all? { |v| v.is_a?(Numeric) && v.finite? }
      end
    end
  end
end
