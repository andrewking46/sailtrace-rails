module Recordings
  class LocationProcessorService
    WINDOW_SIZE = 10
    BASE_PROCESS_NOISE = 0.5
    BATCH_SIZE = 500

    def initialize(recording)
      @recording = recording
      @speed_calculator = Gps::SmoothedSpeedCalculator.new(window_size: WINDOW_SIZE)
      @filter = Gps::KalmanFilter.new(BASE_PROCESS_NOISE)
    end

    def process
      previous_location = nil
      updates = []

      @recording.recorded_locations.find_in_batches(batch_size: BATCH_SIZE).with_index do |batch, batch_index|
        batch.each_with_index do |location, index|
          result = process_location(location, previous_location)
          if result
            updates << result
          else
            Rails.logger.warn "Location #{location.id} processing returned nil"
          end
          previous_location = location
        end

        RecordedLocation.upsert_all(
          updates,
          update_only: [:adjusted_latitude, :adjusted_longitude],
          returning: false
        )
      end
    end

    private

    def process_location(location, previous_location)
      if previous_location
        process_with_previous(location, previous_location)
      else
        initialize_filter(location)
        nil
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      ErrorNotifierService.notify(e, context: { location_id: location.id, recording_id: @recording.id })
      nil
    rescue StandardError => e
      ErrorNotifierService.notify(e, context: { location_id: location.id, recording_id: @recording.id })
      raise
    end

    def process_with_previous(location, previous_location)
      time_diff = (location.created_at - previous_location.created_at).to_f
      instant_speed = calculate_instant_speed(previous_location, location, time_diff)

      result = apply_kalman_filter(location, instant_speed)
      result
    end

    def calculate_instant_speed(prev_loc, curr_loc, time_diff)
      speed = @speed_calculator.add_point(
        prev_loc.latitude, prev_loc.longitude,
        curr_loc.latitude, curr_loc.longitude,
        time_diff
      )

      speed || BASE_PROCESS_NOISE
    end

    def apply_kalman_filter(location, instant_speed)
      @filter.meters_per_second = [instant_speed, BASE_PROCESS_NOISE].max

      result = @filter.process(location.latitude, location.longitude, location.accuracy, location.created_at.to_f * 1000)

      if result && @filter.latitude.finite? && @filter.longitude.finite?
        {
          id: location.id,
          latitude: location.latitude,
          longitude: location.longitude,
          recording_id: location.recording_id,
          adjusted_latitude: @filter.latitude,
          adjusted_longitude: @filter.longitude
        }
      else
        {
          id: location.id,
          latitude: location.latitude,
          longitude: location.longitude,
          recording_id: location.recording_id,
          adjusted_latitude: location.latitude,
          adjusted_longitude: location.longitude
        }
      end
    end

    def initialize_filter(location)
      @filter.set_state(location.latitude, location.longitude, location.accuracy, location.created_at.to_f * 1000)
    end
  end
end
