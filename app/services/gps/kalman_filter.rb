# frozen_string_literal: true

module Gps
  # KalmanFilter implements a simple Kalman filter for smoothing GPS data
  class KalmanFilter
    attr_reader :timestamp, :latitude, :longitude, :variance

    # Minimum accuracy to prevent division by zero and unrealistic precision
    MIN_ACCURACY = 1.0

    def initialize
      # Initialize variance to a negative value to indicate uninitialized state
      @variance = -1.0
    end

    # Set the initial state of the filter
    # @param lat [Float] Initial latitude
    # @param lng [Float] Initial longitude
    # @param accuracy [Float] GPS accuracy in meters
    # @param timestamp [Float] Unix timestamp in seconds
    def set_state(lat, lng, accuracy, timestamp)
      @latitude = lat.to_f
      @longitude = lng.to_f
      # Square the accuracy to get variance, ensure it's not below minimum
      @variance = [ accuracy.to_f, MIN_ACCURACY ].max**2
      @timestamp = timestamp.to_f
    end

    # Update the filter with a new measurement
    # @param lat [Float] Measured latitude
    # @param lng [Float] Measured longitude
    # @param accuracy [Float] GPS accuracy in meters
    # @param timestamp [Float] Unix timestamp in seconds
    # @param speed [Float] Estimated speed in meters per second
    # @return [Hash, nil] Filtered coordinates or nil if input is invalid
    def update(lat, lng, accuracy, timestamp, speed)
      return nil unless valid_input?(lat, lng, accuracy, timestamp, speed)

      accuracy = [ accuracy.to_f, MIN_ACCURACY ].max

      if @variance.negative?
        set_state(lat, lng, accuracy, timestamp)
        return { lat: @latitude, lng: @longitude }
      end

      perform_filter_operations(lat, lng, accuracy, timestamp, speed)
    end

    private

    # Validate input to ensure all values are numeric and finite
    def valid_input?(*values)
      values.all? { |value| value.is_a?(Numeric) && value.finite? }
    end

    # Perform Kalman filter calculations
    def perform_filter_operations(lat_measurement, lng_measurement, accuracy, timestamp, speed)
      # Calculate time difference in seconds
      time_inc = (timestamp - @timestamp).round(3)

      # If time hasn't advanced, just update the state and return
      if time_inc <= 0
        set_state(lat_measurement, lng_measurement, accuracy, timestamp)
        return { lat: @latitude, lng: @longitude }
      end

      # Predict step: Increase variance based on time and speed
      @variance += time_inc * speed * speed
      @timestamp = timestamp

      # Update step: Calculate Kalman gain
      kalman_gain = @variance / (@variance + accuracy * accuracy)

      # Update latitude and longitude estimates
      @latitude += kalman_gain * (lat_measurement - @latitude)
      @longitude += kalman_gain * (lng_measurement - @longitude)

      # Update variance
      @variance *= (1.0 - kalman_gain)

      # Return filtered coordinates, or original coordinates if results are invalid
      if @latitude.finite? && @longitude.finite? && @variance.finite?
        { lat: @latitude, lng: @longitude }
      else
        { lat: lat_measurement, lng: lng_measurement }
      end
    end
  end
end
