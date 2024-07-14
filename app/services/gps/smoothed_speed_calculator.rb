module Gps
  class SmoothedSpeedCalculator
    def initialize(window_size:)
      @window_size = window_size
      @distances = []
      @times = []
    end

    def add_point(lat1, lon1, lat2, lon2, time_diff)
      Rails.logger.debug "SmoothedSpeedCalculator: Adding point (#{lat1}, #{lon1}) to (#{lat2}, #{lon2}) with time_diff #{time_diff}"
      return 0 unless valid_input?(lat1, lon1, lat2, lon2, time_diff)

      distance = DistanceCalculator.distance_in_meters(lat1, lon1, lat2, lon2)
      Rails.logger.debug "SmoothedSpeedCalculator: Calculated distance: #{distance} meters"
      @distances << distance
      @times << time_diff

      @distances.shift if @distances.size > @window_size
      @times.shift if @times.size > @window_size

      average_speed
      Rails.logger.debug "SmoothedSpeedCalculator: Calculated average speed: #{average_speed} m/s"
      average_speed
    end

    private

    def average_speed
      total_distance = @distances.sum
      total_time = @times.sum
      Rails.logger.debug "SmoothedSpeedCalculator: Window size: #{@distances.size}, Total distance: #{total_distance}, Total time: #{total_time}"
      total_time.positive? ? total_distance / total_time : 0
    end

    def valid_input?(*values)
      values.all? { |value| value.is_a?(Numeric) } && values.last.positive?
    end
  end
end
