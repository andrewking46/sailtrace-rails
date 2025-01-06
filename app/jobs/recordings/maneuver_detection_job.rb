# app/jobs/recordings/maneuver_detection_job.rb
# frozen_string_literal: true

module Recordings
  class ManeuverDetectionJob < ApplicationJob
    queue_as :default

    def perform(recording_id:, wind_direction_degrees:)
      Recordings::ManeuverDetectionService.new(
        recording_id: recording_id,
        wind_direction_degrees: wind_direction_degrees
      ).call
    end
  end
end
