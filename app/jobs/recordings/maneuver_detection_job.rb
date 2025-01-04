# app/jobs/recordings/maneuver_detection_job.rb
# frozen_string_literal: true

module Recordings
  class ManeuverDetectionJob < ApplicationJob
    queue_as :default

    def perform(recording_id:)
      Recordings::ManeuverDetectionService.new(recording_id).call
    end
  end
end
