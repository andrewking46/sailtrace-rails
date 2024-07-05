module Recordings
  class LocationProcessorService
    WINDOW_SIZE = 10
    BASE_PROCESS_NOISE = 0.5

    def initialize(recording)
      @recording = recording
      @speed_calculator = Gps::SmoothedSpeedCalculator.new(window_size: WINDOW_SIZE)
      @filter = Gps::KalmanFilter.new(BASE_PROCESS_NOISE)
    end

    def process
      Rails.logger.info "interpolate_curve"
      previous_location = nil

      @recording.recorded_locations.order(:created_at).find_each do |location|
        process_location(location, previous_location)
        previous_location = location
      end
    end

    private

    def process_location(location, previous_location)
      Rails.logger.info "process_location"
      if previous_location
        process_with_previous(location, previous_location)
      else
        initialize_filter(location)
      end
    rescue StandardError => e
      ErrorNotifierService.notify(e, context: { location_id: location.id, recording_id: @recording.id })
    end

    def process_with_previous(location, previous_location)
      Rails.logger.info "process_with_previous"
      time_diff = (location.created_at - previous_location.created_at).to_f.round(2)
      instant_speed = calculate_instant_speed(previous_location, location, time_diff)
      apply_kalman_filter(location, instant_speed)
      update_location(location)
    end

    def calculate_instant_speed(prev_loc, curr_loc, time_diff)
      Rails.logger.info "calculate_instant_speed"
      @speed_calculator.add_point(
        prev_loc.latitude, prev_loc.longitude,
        curr_loc.latitude, curr_loc.longitude,
        time_diff
      )
    end

    def apply_kalman_filter(location, instant_speed)
      Rails.logger.info "apply_kalman_filter"
      @filter.meters_per_second = [instant_speed, BASE_PROCESS_NOISE].max
      @filter.process(location.latitude, location.longitude, location.accuracy, location.created_at.to_f * 1000)
    end

    def initialize_filter(location)
      Rails.logger.info "initialize_filter"
      @filter.set_state(location.latitude, location.longitude, location.accuracy, location.created_at.to_f * 1000)
    end

    def update_location(location)
      Rails.logger.info "update_location"
      location.update(
        adjusted_latitude: @filter.latitude,
        adjusted_longitude: @filter.longitude
      )
    end
  end
end
