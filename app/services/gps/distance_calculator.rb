module Gps
  class DistanceCalculator
    EARTH_RADIUS_KM = 6371.0 # Earth's radius in kilometers
    RAD_PER_DEG = Math::PI / 180.0

    class << self
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

      def valid_coordinates?(*values)
        values.all? { |v| v.is_a?(Numeric) && v.finite? }
      end
    end
  end
end
