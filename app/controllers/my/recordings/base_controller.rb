module My
  module Recordings
    class BaseController < My::BaseController
      before_action :set_recording
      before_action :set_base_breadcrumbs

      private

      def set_base_breadcrumbs
        add_breadcrumb("Recordings", my_recordings_path)
        add_breadcrumb(@recording.name || @recording.started_at.in_time_zone(@recording.time_zone).strftime("%A, %b %d, %Y at %l:%M%p"), my_recording_path(@recording))
      end

      def set_recording
        @recording = Current.user.recordings.find(params[:recording_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Recording not found" }, status: :not_found
      end
    end
  end
end
