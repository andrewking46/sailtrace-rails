# frozen_string_literal: true

require "zlib"

module Api
  module V1
    module Recordings
      class RecordedLocationsController < BaseController
        def index
          compressed_data = CacheManager.read("#{@recording.cache_key}/recorded_locations")

          if compressed_data
            json_string = Zlib::Inflate.inflate(compressed_data)
            render json: json_string
          else
            render json: { message: "Location data has not been cached yet. Please try again later." }, status: :accepted
          end
        end

        def create
          if @recording.ended?
            render json: { error: "Recording has already ended" }, status: :unprocessable_entity
            return
          end

          new_locations = build_locations

          if new_locations.all?(&:valid?)
            RecordedLocation.transaction do
              new_locations.each(&:save!)
            end
            render json: new_locations, each_serializer: RecordedLocationSerializer, status: :created
          else
            render json: { errors: new_locations.map(&:errors) }, status: :unprocessable_entity
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
