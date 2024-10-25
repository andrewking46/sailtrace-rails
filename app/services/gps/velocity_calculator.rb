# frozen_string_literal: true

module Gps
  # VelocityCalculator calculates the velocity between two points
  # Velocity is calculated as the distance between points divided by the time difference
  module VelocityCalculator
    module_function

    # Calculates the velocity between two points
    # @param start_point [Object] Starting point with adjusted_latitude, adjusted_longitude, and recorded_at methods
    # @param end_point [Object] Ending point with adjusted_latitude, adjusted_longitude, and recorded_at methods
    # @return [Float] Velocity in knots (nautical miles per hour)
    def calculate(start_point, end_point)
      distance = DistanceCalculator.distance_in_meters(
        start_point.adjusted_latitude, start_point.adjusted_longitude,
        end_point.adjusted_latitude, end_point.adjusted_longitude
      )
      time_diff = (end_point.recorded_at - start_point.recorded_at).to_f

      # Convert m/s to knots (1 m/s = 1.94384 knots)
      # Using to_f to ensure floating-point division
      (distance / time_diff.to_f) * 1.94384
    end
  end
end
