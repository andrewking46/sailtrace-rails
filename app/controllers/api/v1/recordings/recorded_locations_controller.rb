module Api
  module V1
    module Recordings
      class RecordedLocationsController < BaseController
        def index
          @recorded_locations = @recording.recorded_locations.where.not(adjusted_latitude: nil,
                                                                        adjusted_longitude: nil).order(recorded_at: :asc)
          render json: @recorded_locations, each_serializer: RecordedLocationSerializer
        end

        def create
          if @recording.ended?
            render json: { error: "Recording has already ended" }, status: :unprocessable_entity
            return
          end

          locations_to_create = build_locations

          if locations_to_create.all? { |loc| loc.valid? }
            RecordedLocation.transaction do
              locations_to_create.each(&:save!)
            end
            render json: locations_to_create, each_serializer: RecordedLocationSerializer, status: :created
          else
            render json: { errors: locations_to_create.map(&:errors) }, status: :unprocessable_entity
          end
        end

        private

        def build_locations
          recorded_location_params.map do |location_params|
            @recording.recorded_locations.build(location_params)
          end
        end

        def recorded_location_params
          params.require(:recorded_locations).map do |location|
            location.compact_blank.permit(:latitude, :longitude, :accuracy, :recorded_at)
          end
        end
      end
    end
  end
end
