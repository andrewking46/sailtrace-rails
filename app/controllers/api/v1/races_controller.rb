# frozen_string_literal: true

module Api
  module V1
    class RacesController < BaseController
      before_action :set_race, only: [ :show ]

      def show
        render json: @race, serializer: RaceSerializer
      end

      private

      def set_race
        @race = Race.find(params[:id])
      end
    end
  end
end
