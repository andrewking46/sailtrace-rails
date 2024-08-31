module Admin
  class RecordingsController < BaseController
    before_action :set_recording, only: %i[show destroy]

    def index
      @recordings = Recording.all.includes(:boat, :user).order(created_at: :desc)
    end

    def show; end

    def destroy
      @recording.destroy!

      respond_to do |format|
        format.html { redirect_to admin_recordings_url, notice: "Recording deleted" }
        format.json { head :no_content }
      end
    end

    private

    def set_recording
      @recording = Recording.find(params[:id])
    end
  end
end
