class ProcessRecordingLocationsJob < ApplicationJob
  queue_as :default
  WINDOW_SIZE = 10
  BASE_PROCESS_NOISE = 0.5

  def perform(recording_id)
    recording = Recording.find(recording_id)
    speed_calculator = SmoothedSpeedCalculator.new(window_size: WINDOW_SIZE)
    filter = KalmanFilter.new(BASE_PROCESS_NOISE)
    previous_location = nil

    recording.recorded_locations.order(:created_at).each do |location|
      if previous_location
        time_diff = (location.created_at - previous_location.created_at).to_f
        instant_speed = speed_calculator.add_point(
          previous_location.latitude, previous_location.longitude,
          location.latitude, location.longitude,
          time_diff
        )

        filter.q_metres_per_second = [instant_speed, BASE_PROCESS_NOISE].max
        filter.process(location.latitude, location.longitude, location.accuracy, location.created_at.to_f * 1000)

        location.update(
          adjusted_latitude: filter.latitude,
          adjusted_longitude: filter.longitude
        )
      else
        filter.set_state(location.latitude, location.longitude, location.accuracy, location.created_at.to_f * 1000)
      end

      previous_location = location
    end
  end
end
