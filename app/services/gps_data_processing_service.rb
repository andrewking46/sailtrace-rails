class GpsDataProcessingService
  attr_reader :locations

  ACCURACY_THRESHOLD = 10

  def initialize(locations)
    @locations = locations
  end

  def process
    clean_data
    interpolate_curve_with_gaps
  end

  private

  # Remove points with accuracy less than the threshold and any other noise in the data
  def clean_data
    remove_outliers
    apply_weighted_moving_average
  end

  # Remove any points that have an accuracy below a certain threshold
  def remove_outliers
    @locations.select! { |loc| loc[:accuracy] <= ACCURACY_THRESHOLD }
  end

  # Apply a weighted moving average where the weights are inversely proportional to the accuracy
  def apply_weighted_moving_average
    @locations = @locations.each_with_index.map do |location, index|
      window = determine_window(index)
      total_weight = window.sum { |loc| 1.0 / loc[:accuracy] }

      weighted_lat = window.sum { |loc| loc[:latitude] * (1.0 / loc[:accuracy]) } / total_weight
      weighted_lng = window.sum { |loc| loc[:longitude] * (1.0 / loc[:accuracy]) } / total_weight

      { latitude: weighted_lat, longitude: weighted_lng, accuracy: location[:accuracy], created_at: location[:created_at] }
    end
  end

  def determine_window(index)
    # Calculate window size based on index and ensure we do not go out of bounds
    start_index = [index - 2, 0].max
    end_index = [index + 2, @locations.size - 1].min
    @locations[start_index..end_index]
  end

  # Use cubic spline interpolation to create a smooth path, handling gaps appropriately
  def interpolate_curve_with_gaps
    interpolated_path = []
    # Assuming @locations is sorted by the recorded time
    # We need at least 4 points to perform spline interpolation
    return @locations if @locations.size < 4

    @locations.each_cons(4) do |p0, p1, p2, p3|
      # Check for signal loss or drift between points p1 and p2
      if signal_lost?(p1, p2)
        # Handle the gap by simply preserving it in the output
        interpolated_path << nil
        next
      end

      # Generate points on the Catmull-Rom spline between p1 and p2
      interpolated_path.concat(catmull_rom_points(p0, p1, p2, p3))
    end

    interpolated_path
  end

  def signal_lost?(point1, point2)
    # Define logic to determine if signal is lost, for example, by checking the time gap
    (point2[:created_at] - point1[:created_at]) > acceptable_time_gap
  end

  def catmull_rom_points(p0, p1, p2, p3, steps = 20)
    (1..steps).map do |step|
      t = step.to_f / steps
      {
        latitude: catmull_rom(t, p0[:latitude], p1[:latitude], p2[:latitude], p3[:latitude]),
        longitude: catmull_rom(t, p0[:longitude], p1[:longitude], p2[:longitude], p3[:longitude])
      }
    end
  end

  def catmull_rom(t, p0, p1, p2, p3)
    # Catmull-Rom spline formula
    0.5 * ((2 * p1) +
           (-p0 + p3) * t +
           (2*p0 - 5*p1 + 4*p3 - p2) * t**2 +
           (-p0 + 3*p1 - 3*p3 + p2) * t**3)
  end

  def acceptable_time_gap
    # Define your acceptable time gap in seconds
    60 # seconds
  end

  # Additional methods to support curve fitting and signal loss handling would be here
  # ...
end

# Usage example:
# attributes = %i(latitude longitude accuracy created_at)
# locations = Recording.find(2).recorded_locations.order(created_at: :asc).pluck(*attributes).map { |l| attributes.zip(l).to_h }
# service = GpsDataProcessingService.new(locations)
# smoothed_path = service.process
