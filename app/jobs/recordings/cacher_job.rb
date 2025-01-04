# frozen_string_literal: true

module Recordings
  class CacherJob < ApplicationJob
    queue_as :default
    retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

    def perform(recording_id)
      recording = Recording.find(recording_id)
      Recordings::CacherService.new(recording).cache_recorded_locations
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Could not find Recording #{recording_id} for caching: #{e.message}"
    end

    def self.already_queued_for?(recording_id)
      concurrency_key = "recording_cacher_#{recording_id}"
      job_exists = SolidQueue::Job
                    .where(class_name: name, arguments: [ recording_id ].to_json)
                    .where.not(finished_at: nil)
                    .exists?

      job_exists
    end
  end
end
