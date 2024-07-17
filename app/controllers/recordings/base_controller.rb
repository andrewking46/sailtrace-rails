module Recordings
  class BaseController < ApplicationController
    before_action :set_recording

    private

    def set_recording
      @recording = Current.user.recordings.find(params[:recording_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Recording not found' }, status: :not_found
    end
  end
end
