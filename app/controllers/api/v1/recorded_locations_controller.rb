module Api
  module V1
    class RecordedLocationsController < BaseController
      before_action :set_recording

      def create
        @recorded_location = @recording.recorded_locations.new(recorded_location_params)
        if @recorded_location.save
          render json: @recorded_location, status: :created
        else
          render json: { errors: @recorded_location.errors }, status: :unprocessable_entity
        end
      end

      def batch_create
        ActiveRecord::Base.transaction do
          @recorded_locations = @recording.recorded_locations.create!(batch_locations_params)
        end
        render json: @recorded_locations, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors }, status: :unprocessable_entity
      end

      private

      def set_recording
        @recording = current_user.recordings.find(params[:recording_id])
      end

      def recorded_location_params
        params.require(:recorded_location).permit(:latitude, :longitude, :velocity, :heading, :accuracy, :created_at)
      end

      def batch_locations_params
        params.require(:locations).map do |location|
          location.permit(:latitude, :longitude, :velocity, :heading, :accuracy, :created_at)
        end
      end
    end
  end
end
