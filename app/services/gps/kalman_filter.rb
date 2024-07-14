module Gps
  class KalmanFilter
    attr_reader :timestamp, :latitude, :longitude, :variance
    attr_accessor :meters_per_second

    MIN_ACCURACY = 1.0

    def initialize(meters_per_second)
      @meters_per_second = meters_per_second.to_f
      @variance = -1.0
    end

    def set_state(lat, lng, accuracy, timestamp)
      @latitude = lat.to_f
      @longitude = lng.to_f
      @variance = default_accuracy(accuracy)**2
      @timestamp = timestamp.to_f
    end

    def process(lat_measurement, lng_measurement, accuracy, timestamp)
      unless valid_input?(lat_measurement, lng_measurement, accuracy, timestamp)
        raise ArgumentError, "Invalid input for Kalman filter"
      end

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
      [accuracy.to_f, MIN_ACCURACY].max
    end

    def valid_input?(*values)
      values.all? { |value| value.is_a?(Numeric) }
    end

    def perform_filter_operations(lat_measurement, lng_measurement, accuracy, timestamp)
      time_inc = (timestamp - @timestamp) * 0.001 # Multiply by 0.001 instead of dividing by 1000.0
      return set_state(lat_measurement, lng_measurement, accuracy, timestamp) if time_inc <= 0

      @variance += time_inc * @meters_per_second * @meters_per_second
      @timestamp = timestamp

      kalman_gain = @variance / (@variance + accuracy * accuracy)
      lat_diff = lat_measurement - @latitude
      lng_diff = lng_measurement - @longitude

      @latitude += kalman_gain * lat_diff
      @longitude += kalman_gain * lng_diff
      @variance *= (1.0 - kalman_gain)

      if @latitude.finite? && @longitude.finite? && @variance.finite?
        true
      else
        set_state(lat_measurement, lng_measurement, accuracy, timestamp)
        false
      end
    end
  end
end
