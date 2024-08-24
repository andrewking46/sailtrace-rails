module Api
  module V1
    module Races
      class BaseController < Api::V1::BaseController
        before_action :set_race

        private

        def set_race
          @race = Race.find(params[:race_id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Race not found" }, status: :not_found
        end
      end
    end
  end
end
