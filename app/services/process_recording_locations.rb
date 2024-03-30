class ProcessRecordingLocations
  WINDOW_SIZE = 10
  BASE_PROCESS_NOISE = 0.5 # Increase this value to make the filter more aggressive. The process noise represents the expected amount of noise in your system's model — in this case, how much you expect the boat's velocity to change. Increasing this value tells the Kalman filter that larger changes in speed are expected, thus making it rely more on the model predictions (smoothing out the noise) rather than the incoming measurements which might be noisy.

  def self.perform(recording_id)
    recording = Recording.find_by(id: recording_id)

    speed_calculator = SmoothedSpeedCalculator.new(window_size: WINDOW_SIZE)
    filter = KalmanFilter.new(BASE_PROCESS_NOISE)
    previous_location = nil

    recording.recorded_locations.order(created_at: :asc).each do |location|
      begin
        if previous_location
          time_diff = (location.created_at - previous_location.created_at).to_f.round(2)
          instant_speed = speed_calculator.add_point(
            previous_location.latitude.to_f, previous_location.longitude.to_f,
            location.latitude.to_f, location.longitude.to_f,
            time_diff
          )

          filter.meters_per_second = [instant_speed, BASE_PROCESS_NOISE].max
          filter.process(location.latitude.to_f, location.longitude.to_f, location.accuracy.to_f.round(1), location.created_at.to_f * 1000)

          location.update(
            adjusted_latitude: filter.latitude,
            adjusted_longitude: filter.longitude
          )
        else
          location.update(
            adjusted_latitude: location.latitude,
            adjusted_longitude: location.longitude
          )
          filter.set_state(location.latitude.to_f, location.longitude.to_f, location.accuracy.to_f.round(1), location.created_at.to_f * 1000)
        end

        previous_location = location
      rescue => e
        Rails.logger.error "Error in ProcessRecordingLocations.perform for RecordedLocation #{location.id}: #{e.class} #{e.message}"
      end
    end
  end
end
