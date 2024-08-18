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
      return false unless valid_input?(lat_measurement, lng_measurement, accuracy, timestamp)

      accuracy = default_accuracy(accuracy)

      if @variance.negative?
        set_state(lat_measurement, lng_measurement, accuracy, timestamp)
        return true
      end

      perform_filter_operations(lat_measurement, lng_measurement, accuracy, timestamp)
    end

    def accuracy
      Math.sqrt(@variance)
    end

    private

    def default_accuracy(accuracy)
      [accuracy.to_f, MIN_ACCURACY].max
    end

    def valid_input?(*values)
      values.all? { |value| value.is_a?(Numeric) && value.finite? }
    end

    def perform_filter_operations(lat_measurement, lng_measurement, accuracy, timestamp)
      time_inc = ((timestamp - @timestamp) * 0.001).round(3)
      return set_state(lat_measurement, lng_measurement, accuracy, timestamp) if time_inc <= 0

      @variance += time_inc * @meters_per_second * @meters_per_second
      @timestamp = timestamp

      kalman_gain = @variance / (@variance + accuracy * accuracy)
      @latitude += kalman_gain * (lat_measurement - @latitude)
      @longitude += kalman_gain * (lng_measurement - @longitude)
      @variance *= (1.0 - kalman_gain)

      @latitude.finite? && @longitude.finite? && @variance.finite?
    end
  end
end
