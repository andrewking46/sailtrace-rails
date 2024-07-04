module Api
  module V1
    class RecordingsController < BaseController
      before_action :set_recording, only: [:show, :update]
      before_action :authorize_recording, only: [:show, :update, :destroy]

      def create
        @recording = current_user.recordings.new(recording_params)
        if @recording.save
          render json: @recording, status: :created
        else
          render json: { errors: @recording.errors }, status: :unprocessable_entity
        end
      end

      def show
        render json: @recording
      end

      def update
        if @recording.update(recording_params)
          render json: @recording
        else
          render json: { errors: @recording.errors }, status: :unprocessable_entity
        end
      end

      def end
        if @recording.update(ended_at: params[:ended_at] || Time.current)
          render json: @recording
        else
          render json: { errors: @recording.errors }, status: :unprocessable_entity
        end
      end

      private

      def set_recording
        @recording = current_user.recordings.find(params[:id])
      end

      def authorize_recording
        unless @recording.user_id == current_user.id
          render json: { error: 'You are not authorized to perform this action' }, status: :forbidden
        end
      end

      def recording_params
        params.require(:recording).permit(:name, :started_at, :ended_at, :time_zone, :is_race, :boat_id, :race_id, :start_latitude, :start_longitude)
      end
    end
  end
end
