class DistanceCalculationService
  def initialize(recording)
    @recording = recording
  end

  def calculate
    @recording.recorded_locations.order(created_at: :asc).each_cons(2).sum do |loc1, loc2|
      calculate_distance(loc1, loc2)
    end.round(5)
  end

  private

  def calculate_distance(loc1, loc2)
    GeoDistanceCalculator.distance_in_meters(
      loc1.adjusted_latitude, loc1.adjusted_longitude,
      loc2.adjusted_latitude, loc2.adjusted_longitude
    )
  end
end
