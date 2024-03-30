class KalmanFilter
  attr_accessor :meters_per_second
  attr_reader :timestamp, :latitude, :longitude, :variance

  MIN_ACCURACY = 1.0

  def initialize(meters_per_second)
    @meters_per_second = meters_per_second.to_f.round(2)
    @variance = -1.0
  end

  def set_state(lat, lng, accuracy, timestamp)
    accuracy = default_accuracy_if_nil(accuracy)
    @latitude = lat
    @longitude = lng
    @variance = accuracy**2
    @timestamp = timestamp
  end

  def process(lat_measurement, lng_measurement, accuracy, timestamp)
    unless numeric_values?(lat_measurement, lng_measurement, accuracy, timestamp)
      Rails.logger.error "KalmanFilter.process received non-numeric input"
      return
    end

    begin
      accuracy = default_accuracy_if_nil(accuracy) # * 2 Add a multiplier for more aggressive smoothing

      if @variance < 0
        set_state(lat_measurement, lng_measurement, accuracy, timestamp)
      else
        perform_filter_operations(lat_measurement, lng_measurement, accuracy, timestamp)
      end
    rescue => e
      Rails.logger.error "Error in KalmanFilter.process: #{e.message}"
    end
  end

  def get_accuracy
    Math.sqrt(@variance)
  end

  private

  def default_accuracy_if_nil(accuracy)
    accuracy.nil? ? MIN_ACCURACY : [accuracy, MIN_ACCURACY].max
  end

  def numeric_values?(*values)
    values.all? { |value| value.is_a?(Numeric) }
  end

  def perform_filter_operations(lat_measurement, lng_measurement, accuracy, timestamp)
    time_inc = (timestamp - @timestamp) / 1000.0
    @variance += time_inc * @meters_per_second**2 if time_inc > 0
    @timestamp = timestamp

    kalman_gain = @variance / (@variance + accuracy**2)
    @latitude += kalman_gain * (lat_measurement - @latitude)
    @longitude += kalman_gain * (lng_measurement - @longitude)
    @variance = (1 - kalman_gain) * @variance
  end
end
