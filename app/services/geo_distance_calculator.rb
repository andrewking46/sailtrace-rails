class GeoDistanceCalculator
  EARTH_RADIUS_KM = 6371 # Earth's radius in kilometers

  def self.distance_in_meters(lat1, lon1, lat2, lon2)
    unless numeric_values?(lat1, lon1, lat2, lon2)
      Rails.logger.error "GeoDistanceCalculator.distance_in_meters received non-numeric input"
      return 0
    end

    begin
      radians_per_degree = Math::PI / 180
      dlat_rad = (lat2 - lat1) * radians_per_degree
      dlon_rad = (lon2 - lon1) * radians_per_degree

      lat1_rad, lat2_rad = [lat1, lat2].map { |i| i * radians_per_degree }
      a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2

      c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
      result = EARTH_RADIUS_KM * c * 1000
      result.round(2)
    rescue => e
      Rails.logger.error "Error in GeoDistanceCalculator.distance_in_meters: #{e.message}"
      0 # Return a default distance in case of error
    end
  end

  def self.numeric_values?(*values)
    values.all? { |value| value.is_a?(Numeric) }
  end
end
