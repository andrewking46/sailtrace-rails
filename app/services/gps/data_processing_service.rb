module Gps
  class DataProcessingService
    ACCURACY_THRESHOLD = 10
    WINDOW_SIZE = 5

    def initialize(locations)
      @locations = locations
      Rails.logger.info "First location: #{@locations.first.inspect}"
    end

    def process
      clean_data
      interpolate_curve
    end

    private

    def clean_data
      remove_outliers
      apply_weighted_moving_average
    end

    def remove_outliers
      Rails.logger.info "remove_outliers"
      @locations.select! { |loc| loc[:accuracy] <= ACCURACY_THRESHOLD }
    end

    def apply_weighted_moving_average
      Rails.logger.info "apply_weighted_moving_average"
      @locations = @locations.each_cons(WINDOW_SIZE).map do |window|
        calculate_weighted_average(window)
      end
    end

    def calculate_weighted_average(window)
      Rails.logger.info "calculate_weighted_average"
      total_weight = window.sum { |loc| 1.0 / loc[:accuracy] }
      weighted_lat = window.sum { |loc| loc[:latitude] * (1.0 / loc[:accuracy]) } / total_weight
      weighted_lng = window.sum { |loc| loc[:longitude] * (1.0 / loc[:accuracy]) } / total_weight

      window.middle.merge(latitude: weighted_lat, longitude: weighted_lng)
    end

    def interpolate_curve
      Rails.logger.info "interpolate_curve"
      return @locations if @locations.size < 4

      CatmullRomSpline.new(@locations).interpolate
    end
  end

  class CatmullRomSpline
    def initialize(points, steps = 20)
      @points = points
      @steps = steps
    end

    def interpolate
      Rails.logger.info "interpolate"
      @points.each_cons(4).flat_map do |p0, p1, p2, p3|
        catmull_rom_points(p0, p1, p2, p3)
      end
    end

    private

    def catmull_rom_points(p0, p1, p2, p3)
      Rails.logger.info "catmull_rom_points"
      (1..@steps).map do |step|
        t = step.to_f / @steps
        {
          latitude: catmull_rom(t, p0[:latitude], p1[:latitude], p2[:latitude], p3[:latitude]),
          longitude: catmull_rom(t, p0[:longitude], p1[:longitude], p2[:longitude], p3[:longitude]),
          created_at: interpolate_time(t, p1[:created_at], p2[:created_at])
        }
      end
    end

    def catmull_rom(t, p0, p1, p2, p3)
      Rails.logger.info "catmull_rom"
      0.5 * ((2 * p1) + (-p0 + p3) * t + (2*p0 - 5*p1 + 4*p2 - p3) * t**2 + (-p0 + 3*p1 - 3*p2 + p3) * t**3)
    end

    def interpolate_time(t, t1, t2)
      Rails.logger.info "interpolate_time"
      t1 + (t2 - t1) * t
    end
  end
end
