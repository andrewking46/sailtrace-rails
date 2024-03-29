class GeoDistanceCalculator
  EARTH_RADIUS_KM = 6371 # Earth's radius in kilometers

  def self.distance_in_meters(lat1, lon1, lat2, lon2)
    radians_per_degree = Math::PI / 180
    dlat_rad = (lat2 - lat1) * radians_per_degree
    dlon_rad = (lon2 - lon1) * radians_per_degree

    lat1_rad, lat2_rad = [lat1, lat2].map { |i| i * radians_per_degree }
    a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    (EARTH_RADIUS_KM * c) * 1000
  end
end
