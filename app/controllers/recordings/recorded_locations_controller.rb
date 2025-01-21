# frozen_string_literal: true

module Recordings
  class RecordedLocationsController < BaseController
    #
    # GET /recordings/:recording_id/recorded_locations.json
    #
    # Returns compressed JSON data of all (non-simplified) recorded locations for
    # this Recording, if it's already cached by Recordings::CacherService.
    # If not cached yet, schedules a CacherJob (unless already queued) and returns
    # an HTTP 202 "Please wait" response to the front end.
    #
    def index
      compressed_data = CacheManager.read("#{@recording.cache_key}/recorded_locations")

      if compressed_data
        # Decompress and render
        json_string = Zlib::Inflate.inflate(compressed_data)
        # Note: We can safely render the string as JSON since we built it in the CacherService.
        render json: json_string
      else
        # If not already queued, queue a job to cache
        unless ::Recordings::CacherJob.already_queued_for?(@recording.id)
          ::Recordings::CacherJob.perform_later(@recording.id)
        end

        render json: {
          message: "Location data has not been cached yet. Please try again shortly."
        }, status: :accepted
      end
    end
  end
end
