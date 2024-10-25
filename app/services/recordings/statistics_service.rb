# frozen_string_literal: true

module Recordings
  # StatisticsService calculates overall statistics for the recording
  class StatisticsService
    def initialize(recording)
      @recording = recording
    end

    def process
      @recording.update(
        distance: calculate_distance
        # ,
        # average_speed: calculate_average_speed,
        # max_speed: calculate_max_speed
      )
    end

    private

    def calculate_distance
      @recording.calculate_distance
    end

    def calculate_average_speed
      @recording.recorded_locations.not_simplified.average(:velocity).to_f.round(2)
    end

    def calculate_max_speed
      @recording.recorded_locations.not_simplified.maximum(:velocity).to_f.round(2)
    end
  end
end
