module Gps
  class SmoothedSpeedCalculator
    def initialize(window_size:)
      @window_size = window_size
      @distances = []
      @times = []
    end

    def add_point(lat1, lon1, lat2, lon2, time_diff)
      return 0 unless valid_input?(lat1, lon1, lat2, lon2, time_diff)

      distance = DistanceCalculator.distance_in_meters(lat1, lon1, lat2, lon2)
      @distances << distance
      @times << time_diff

      @distances.shift if @distances.size > @window_size
      @times.shift if @times.size > @window_size

      average_speed
    end

    private

    def average_speed
      total_distance = @distances.sum
      total_time = @times.sum
      total_time.positive? ? total_distance / total_time : 0
    end

    def valid_input?(*values)
      values.all? { |value| value.is_a?(Numeric) } && values.last.positive?
    end
  end
end
