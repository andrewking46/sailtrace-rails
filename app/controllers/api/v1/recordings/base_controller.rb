module Api
  module V1
    module Recordings
      class BaseController < Api::V1::BaseController
        before_action :set_recording

        private

        def set_recording
          @recording = current_user.recordings.find(params[:recording_id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Recording not found' }, status: :not_found
        end
      end
    end
  end
end
