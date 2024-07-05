module Gps
  class KalmanFilter
    attr_accessor :meters_per_second
    attr_reader :timestamp, :latitude, :longitude, :variance

    MIN_ACCURACY = 1.0

    def initialize(meters_per_second)
      @meters_per_second = meters_per_second.to_f.round(2)
      @variance = -1.0
    end

    def set_state(lat, lng, accuracy, timestamp)
      @latitude = lat
      @longitude = lng
      @variance = default_accuracy(accuracy)**2
      @timestamp = timestamp
    end

    def process(lat_measurement, lng_measurement, accuracy, timestamp)
      return unless valid_input?(lat_measurement, lng_measurement, accuracy, timestamp)

      accuracy = default_accuracy(accuracy)

      if @variance.negative?
        set_state(lat_measurement, lng_measurement, accuracy, timestamp)
      else
        perform_filter_operations(lat_measurement, lng_measurement, accuracy, timestamp)
      end
    end

    def accuracy
      Math.sqrt(@variance)
    end

    private

    def default_accuracy(accuracy)
      [accuracy, MIN_ACCURACY].max
    end

    def valid_input?(*values)
      values.all? { |value| value.is_a?(Numeric) }
    end

    def perform_filter_operations(lat_measurement, lng_measurement, accuracy, timestamp)
      time_inc = (timestamp - @timestamp) / 1000.0
      @variance += time_inc * @meters_per_second**2 if time_inc.positive?
      @timestamp = timestamp

      kalman_gain = @variance / (@variance + accuracy**2)
      @latitude += kalman_gain * (lat_measurement - @latitude)
      @longitude += kalman_gain * (lng_measurement - @longitude)
      @variance = (1 - kalman_gain) * @variance
    end
  end
end
