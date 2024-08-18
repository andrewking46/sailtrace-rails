module Api
  module V1
    class RecordingsController < BaseController
      include UserOwnedResource

      before_action :set_recording, only: [:end]

      def index
        @recordings = current_user.recordings.includes(:boat).order(created_at: :desc)
        render json: @recordings, each_serializer: RecordingSerializer
      end

      def create
        @recording = current_user.recordings.new(recording_params)
        if @recording.save
          render json: @recording, serializer: RecordingSerializer, status: :created
        else
          render json: { errors: @recording.errors }, status: :unprocessable_entity
        end
      end

      def show
        render json: @recording, serializer: RecordingSerializer
      end

      def update
        if @recording.update(recording_params)
          render json: @recording, serializer: RecordingSerializer
        else
          render json: { errors: @recording.errors }, status: :unprocessable_entity
        end
      end

      def destroy
        @recording.destroy
        head :no_content
      end

      def end
        if @recording.update(ended_at: params[:ended_at] || Time.current)
          render json: @recording, serializer: RecordingSerializer
        else
          render json: { errors: @recording.errors }, status: :unprocessable_entity
        end
      end

      private

      def set_recording
        @recording = current_user.recordings.find(params[:id])
      end

      def recording_params
        params.require(:recording).compact_blank.permit(:name, :started_at, :ended_at, :time_zone, :is_race, :boat_id, :race_id, :start_latitude, :start_longitude)
      end
    end
  end
end
