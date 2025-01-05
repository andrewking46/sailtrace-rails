# app/jobs/recordings/wind_direction_inference_job.rb
# frozen_string_literal: true

module Recordings
  class WindDirectionInferenceJob < ApplicationJob
    queue_as :default

    def perform(recording_id:)
      Recordings::WindDirectionInferenceService.new(recording_id).call
    end
  end
end
