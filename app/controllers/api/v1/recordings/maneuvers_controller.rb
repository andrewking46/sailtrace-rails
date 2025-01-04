# app/controllers/api/v1/recordings/maneuvers_controller.rb
# frozen_string_literal: true

module Api
  module V1
    module Recordings
      class ManeuversController < BaseController
        # GET /api/v1/recordings/:recording_id/maneuvers
        #
        # Returns a JSON array of Maneuvers for the given Recording, in ascending order by occurred_at.
        def index
          @maneuvers = @recording.maneuvers.order(:occurred_at)
          render json: @maneuvers, each_serializer: ManeuverSerializer
        end
      end
    end
  end
end
