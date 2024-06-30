class Recordings::ReplaysController < ApplicationController
  before_action :set_recording

  def show; end

  private
    def set_recording
      @recording = Recording.find(params[:recording_id])
    end
end
