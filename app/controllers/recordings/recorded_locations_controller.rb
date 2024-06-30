class Recordings::RecordedLocationsController < ApplicationController
  before_action :set_recording

  def index
    @recorded_locations = @recording.recorded_locations.order(created_at: :asc)

    render json: @recorded_locations
  end

  private
    def set_recording
      @recording = Recording.find(params[:recording_id])
    end
end
