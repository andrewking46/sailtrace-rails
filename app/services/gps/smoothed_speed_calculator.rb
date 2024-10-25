# frozen_string_literal: true

module Gps
  # SmoothedSpeedCalculator implements a sliding window algorithm to calculate
  # smoothed speed values from GPS coordinates. It maintains a fixed-size window
  # of recent measurements to reduce noise and provide more stable speed calculations.
  #
  # Performance optimizations:
  # - Uses Array#push/shift for efficient FIFO queue operations
  # - Preallocates arrays to avoid resizing
  # - Minimizes object allocations in hot paths
  # - Uses Float operations for better performance
  class SmoothedSpeedCalculator
    # Conversion factor from meters per second to knots
    KNOTS_CONVERSION = 1.94384

    # Initialize all resources needed for speed calculation
    # @param window_size [Integer] Number of points to use in moving average
    # @param output_knots [Boolean] Whether to output speed in knots (true) or m/s (false)
    def initialize(window_size:, output_knots: false)
      @window_size = window_size
      @output_knots = output_knots

      # Preallocate arrays with exact size to avoid resizing
      # Using Array.new with size prevents array growth overhead
      @distances = Array.new(window_size, 0.0)
      @times = Array.new(window_size, 0.0)
      @current_size = 0
      @array_index = 0
    end

    # Calculate smoothed speed based on new GPS coordinates
    # @param lat1 [Float] Previous latitude
    # @param lon1 [Float] Previous longitude
    # @param lat2 [Float] Current latitude
    # @param lon2 [Float] Current longitude
    # @param time_diff [Float] Time difference between points in seconds
    # @return [Float] Smoothed speed in knots or m/s depending on configuration
    def add_point(lat1, lon1, lat2, lon2, time_diff)
      # Early return for invalid input to avoid unnecessary calculations
      return 0.0 unless valid_input?(lat1, lon1, lat2, lon2, time_diff)

      # Calculate distance and update sliding windows
      distance = DistanceCalculator.distance_in_meters(lat1, lon1, lat2, lon2)
      update_windows(distance, time_diff)
      calculate_average_speed
    end

    # Reset calculator state
    # @note This method should be called when processing a new batch of points
    def reset
      # More efficient than clear - allows GC to collect old values
      @distances = Array.new(@window_size, 0.0)
      @times = Array.new(@window_size, 0.0)
      @current_size = 0
      @array_index = 0
    end

    private

    # Update sliding windows with new measurements using circular buffer approach
    # @param distance [Float] New distance measurement in meters
    # @param time_diff [Float] New time difference in seconds
    def update_windows(distance, time_diff)
      # Use circular buffer for better performance than shift/push
      @distances[@array_index] = distance
      @times[@array_index] = time_diff

      @current_size = [ @current_size + 1, @window_size ].min
      @array_index = (@array_index + 1) % @window_size
    end

    # Calculate average speed from current window measurements
    # @return [Float] Average speed in configured units
    def calculate_average_speed
      return 0.0 if @current_size.zero?

      # Sum only the active portion of the arrays
      total_distance = 0.0
      total_time = 0.0

      @current_size.times do |i|
        total_distance += @distances[i]
        total_time += @times[i]
      end

      return 0.0 unless total_time.positive?

      # Calculate speed and apply conversion if needed
      speed = total_distance / total_time
      @output_knots ? speed * KNOTS_CONVERSION : speed
    end

    # Validate all input values are usable
    # @return [Boolean] true if all inputs are valid numbers
    def valid_input?(*values)
      values.all? { |value| value.is_a?(Numeric) && value.finite? } && values.last.positive?
    end
  end
end
