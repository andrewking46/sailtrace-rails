# app/jobs/races/course_mark_detection_job.rb
# frozen_string_literal: true

module Races
  class CourseMarkDetectionJob < ApplicationJob
    queue_as :default

    def perform(race_id:)
      Races::CourseMarkDetectionService.new(race_id: race_id).call
    end
  end
end
