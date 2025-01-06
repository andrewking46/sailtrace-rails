# app/controllers/api/v1/races/course_marks_controller.rb
# frozen_string_literal: true

module Api
  module V1
    module Races
      class CourseMarksController < BaseController
        # GET /api/v1/races/:race_id/course_marks
        #
        # Returns a JSON array of CourseMarks for the given Race
        def index
          @course_marks = @race.course_marks.high_confidence
          render json: @course_marks, each_serializer: CourseMarkSerializer
        end
      end
    end
  end
end
