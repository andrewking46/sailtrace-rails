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
      Rails.logger.debug "KalmanFilter: Processing measurement (#{lat_measurement}, #{lng_measurement}) with accuracy #{accuracy} at timestamp #{timestamp}"

      unless valid_input?(lat_measurement, lng_measurement, accuracy, timestamp)
        Rails.logger.error "KalmanFilter: Invalid input detected"
        raise ArgumentError, "Invalid input for Kalman filter"
      end

      accuracy = default_accuracy(accuracy)
      Rails.logger.debug "KalmanFilter: Using accuracy: #{accuracy}"

      if @variance.negative?
        Rails.logger.debug "KalmanFilter: Negative variance, setting initial state"
        set_state(lat_measurement, lng_measurement, accuracy, timestamp)
      else
        Rails.logger.debug "KalmanFilter: Performing filter operations"
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
      time_inc = ((timestamp - @timestamp) * 0.001).round(3)
      Rails.logger.debug "KalmanFilter: Time increment: #{time_inc}"

      if time_inc <= 0
        Rails.logger.warn "KalmanFilter: Non-positive time increment, resetting state"
        return set_state(lat_measurement, lng_measurement, accuracy, timestamp)
      end

      @variance = (@variance + time_inc * @meters_per_second * @meters_per_second).round(8)
      @timestamp = timestamp

      kalman_gain = (@variance / (@variance + accuracy * accuracy)).round(8)
      lat_diff = (lat_measurement - @latitude).round(8)
      lng_diff = (lng_measurement - @longitude).round(8)

      Rails.logger.debug "KalmanFilter: Kalman gain: #{kalman_gain}, Lat diff: #{lat_diff}, Lng diff: #{lng_diff}"

      @latitude = (@latitude + kalman_gain * lat_diff).round(6)
      @longitude = (@longitude + kalman_gain * lng_diff).round(6)
      @variance = (@variance * (1.0 - kalman_gain)).round(8)

      Rails.logger.debug "KalmanFilter: Updated state - Lat: #{@latitude}, Lng: #{@longitude}, Variance: #{@variance}"

      if @latitude.finite? && @longitude.finite? && @variance.finite?
        true
      else
        Rails.logger.warn "KalmanFilter: Invalid state detected, resetting"
        set_state(lat_measurement, lng_measurement, accuracy, timestamp)
        false
      end
    end
  end
end
