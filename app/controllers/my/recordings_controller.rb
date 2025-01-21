module My
  class RecordingsController < BaseController
    before_action :set_recording, only: %i[show edit update destroy]

    def index
      @recordings = Current.user.recordings.includes(:boat).order(created_at: :desc)
    end

    def show; end

    def edit; end

    def update
      if @recording.update(recording_params)
        redirect_to my_recording_path(@recording), notice: "Recording updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @recording.destroy!
      redirect_to my_recordings_path, notice: "Recording deleted"
    end

    private

    def set_recording
      @recording = Current.user.recordings.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to my_recordings_path, alert: "Recording not found"
    end

    def recording_params
      params.require(:recording).compact_blank.permit(:name, :started_at, :ended_at, :time_zone, :is_race, :boat_id, :race_id)
    end
  end
end
