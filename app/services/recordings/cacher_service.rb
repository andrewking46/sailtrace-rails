# frozen_string_literal: true

require "zlib"

# This service builds & caches the "locations" JSON for the full array of RecordedLocations
module Recordings
  class CacherService
    def initialize(recording)
      @recording = recording
    end

    # Build a "locations" JSON containing the array of all relevant RecordedLocations
    def cache_recorded_locations
      json = generate_recorded_locations_json
      compressed = Zlib::Deflate.deflate(json)
      CacheManager.write("#{@recording.cache_key}/recorded_locations", compressed, expires_in: 28.days)
    end

    private

    def generate_recorded_locations_json
      buffer = StringIO.new
      buffer << "{"
      buffer << %("recording_id":#{@recording.id},)
      buffer << %("recorded_locations":[)

      first = true
      @recording.recorded_locations
                .chronological
                .processed
                .not_simplified
                .find_in_batches(batch_size: 100) do |batch|
        batch.each do |loc|
          buffer << "," unless first
          first = false
          buffer << "{"
          buffer << %("id":#{loc.id},)
          buffer << %("recording_id":#{loc.recording_id},)
          buffer << %("adjusted_latitude":#{loc.adjusted_latitude.to_json},)
          buffer << %("adjusted_longitude":#{loc.adjusted_longitude.to_json},)
          buffer << %("velocity":#{loc.velocity.to_json},)
          buffer << %("heading":#{loc.heading.to_json},)
          buffer << %("recorded_at":#{loc.recorded_at.to_json})
          buffer << "}"
        end
      end

      buffer << "]}"
      buffer.string
    end
  end
end
