json.cache! [ "v#{CacheManager::CACHE_VERSION}", recording ], expires_in: 1.day do
  json.extract! recording, :id, :started_at, :ended_at, :time_zone, :start_latitude, :start_longitude, :is_race,
                :created_at

  json.boat do
    json.extract! recording.boat, :name, :registration_country, :sail_number, :hull_color
  end

  json.recorded_locations recording.recorded_locations.not_simplified.chronological do |recorded_location|
    json.extract! recorded_location, :id, :accuracy, :velocity, :heading, :adjusted_latitude,
                  :adjusted_longitude, :recorded_at
  end

  json.url recording_url(recording, format: :json)
end
