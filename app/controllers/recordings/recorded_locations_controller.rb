module Recordings
  class RecordedLocationsController < BaseController
    def index
      @recorded_locations = @recording.recorded_locations.order(recorded_at: :asc)
      render json: @recorded_locations
    end

    def create
      if @recording.ended?
        render json: { error: 'Recording has already ended' }, status: :unprocessable_entity
        return
      end

      @locations = @recording.recorded_locations.build(recorded_location_params)

      if @locations.all?(&:valid?)
        RecordedLocation.transaction do
          @locations.each(&:save!)
        end
        render json: @locations, status: :created
      else
        render json: { errors: @locations.map(&:errors) }, status: :unprocessable_entity
      end
    end

    private

    def recorded_location_params
      params.require(:recorded_locations).map do |location|
        location.compact_blank.permit(:latitude, :longitude, :accuracy, :recorded_at)
      end
    end
  end
end
