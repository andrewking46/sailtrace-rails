class KalmanFilter
  attr_accessor :meters_per_second
  attr_reader :timestamp, :latitude, :longitude, :variance

  MIN_ACCURACY = 1

  def initialize(meters_per_second)
    @meters_per_second = meters_per_second
    @variance = -1
  end

  def set_state(lat, lng, accuracy, timestamp)
    accuracy = default_accuracy_if_nil(accuracy)
    @latitude = lat
    @longitude = lng
    @variance = accuracy**2
    @timestamp = timestamp
  end

  def process(lat_measurement, lng_measurement, accuracy, timestamp)
    accuracy = default_accuracy_if_nil(accuracy) * 2

    if @variance < 0
      set_state(lat_measurement, lng_measurement, accuracy, timestamp)
    else
      time_inc = (timestamp - @timestamp) / 1000.0
      @variance += time_inc * @meters_per_second**2 if time_inc > 0
      @timestamp = timestamp

      kalman_gain = @variance / (@variance + accuracy**2)
      @latitude += kalman_gain * (lat_measurement - @latitude)
      @longitude += kalman_gain * (lng_measurement - @longitude)
      @variance = (1 - kalman_gain) * @variance
    end
  end

  def get_accuracy
    Math.sqrt(@variance)
  end

  private

  def default_accuracy_if_nil(accuracy)
    accuracy.nil? ? MIN_ACCURACY : [accuracy, MIN_ACCURACY].max
  end
end
