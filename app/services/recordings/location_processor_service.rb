module Recordings
  class LocationProcessorService
    WINDOW_SIZE = 10
    BASE_PROCESS_NOISE = 0.5
    BATCH_SIZE = 1000

    def initialize(recording)
      @recording = recording
      @speed_calculator = Gps::SmoothedSpeedCalculator.new(window_size: WINDOW_SIZE)
      @filter = Gps::KalmanFilter.new(BASE_PROCESS_NOISE)
    end

    def process
      Rails.logger.info "Starting LocationProcessorService for Recording #{@recording.id}"
      previous_location = nil
      updates = []

      @recording.recorded_locations.find_in_batches(batch_size: BATCH_SIZE).with_index do |batch, batch_index|
        Rails.logger.info "Processing batch #{batch_index + 1} for Recording #{@recording.id}"

        batch.each_with_index do |location, index|
          Rails.logger.debug "Processing location #{location.id} (#{index + 1} in batch, #{batch_index * BATCH_SIZE + index + 1} overall)"
          result = process_location(location, previous_location)
          if result
            updates << result
            Rails.logger.debug "Location #{location.id} processed successfully: #{result.inspect}"
          else
            Rails.logger.warn "Location #{location.id} processing returned nil"
          end
          previous_location = location
        end

        Rails.logger.info "Upserting #{updates.size} records for Recording #{@recording.id}"
        Rails.logger.debug "Updates array before upsert: #{updates.inspect}"
        RecordedLocation.upsert_all(
          updates,
          update_only: [:adjusted_latitude, :adjusted_longitude],
          returning: false
        )
      end

      Rails.logger.info "Completed LocationProcessorService for Recording #{@recording.id}"
    end

    private

    def process_location(location, previous_location)
      if previous_location
        process_with_previous(location, previous_location)
      else
        Rails.logger.debug "Initializing filter for first location #{location.id}"
        initialize_filter(location)
        nil
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      Rails.logger.error "Database error processing location #{location.id}: #{e.message}"
      ErrorNotifierService.notify(e, context: { location_id: location.id, recording_id: @recording.id })
      nil
    rescue StandardError => e
      Rails.logger.error "Unexpected error processing location #{location.id}: #{e.message}\n#{e.backtrace.join("\n")}"
      ErrorNotifierService.notify(e, context: { location_id: location.id, recording_id: @recording.id })
      raise
    end

    def process_with_previous(location, previous_location)
      Rails.logger.debug "Processing location #{location.id} with previous location #{previous_location.id}"
      time_diff = (location.created_at - previous_location.created_at).to_f
      instant_speed = calculate_instant_speed(previous_location, location, time_diff)
      Rails.logger.debug "Calculated instant speed: #{instant_speed} for location #{location.id}"

      result = apply_kalman_filter(location, instant_speed)
      Rails.logger.debug "Kalman filter result for location #{location.id}: #{result.inspect}"
      result
    end

    def calculate_instant_speed(prev_loc, curr_loc, time_diff)
      speed = @speed_calculator.add_point(
        prev_loc.latitude, prev_loc.longitude,
        curr_loc.latitude, curr_loc.longitude,
        time_diff
      )
      Rails.logger.debug "SmoothedSpeedCalculator returned speed: #{speed} for location #{curr_loc.id}"
      speed || BASE_PROCESS_NOISE
    end

    def apply_kalman_filter(location, instant_speed)
      Rails.logger.debug "Applying Kalman filter to location #{location.id} with instant_speed: #{instant_speed}"
      @filter.meters_per_second = [instant_speed, BASE_PROCESS_NOISE].max
      Rails.logger.debug "Set Kalman filter meters_per_second to: #{@filter.meters_per_second}"

      result = @filter.process(location.latitude, location.longitude, location.accuracy, location.created_at.to_f * 1000)

      if result && @filter.latitude.finite? && @filter.longitude.finite?
        Rails.logger.debug "Kalman filter produced valid result for location #{location.id}: lat=#{@filter.latitude}, lon=#{@filter.longitude}"
        {
          id: location.id,
          latitude: location.latitude,
          longitude: location.longitude,
          recording_id: location.recording_id,
          adjusted_latitude: @filter.latitude,
          adjusted_longitude: @filter.longitude
        }
      else
        Rails.logger.warn "Kalman filter produced invalid result for location #{location.id}. Using original coordinates."
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
