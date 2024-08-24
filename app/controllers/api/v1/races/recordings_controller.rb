# frozen_string_literal: true

module Api
  module V1
    module Races
      class RecordingsController < BaseController
        def index
          @recordings = @race.recordings.includes(:boat, :recorded_locations)
          render json: @recordings, each_serializer: RecordingSerializer
        end
      end
    end
  end
end
