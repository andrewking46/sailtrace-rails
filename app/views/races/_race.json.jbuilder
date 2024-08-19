json.cache! ["v#{CacheManager::CACHE_VERSION}", race.cache_key] do
  json.extract! race, :id, :name, :started_at, :start_latitude, :start_longitude, :created_at, :updated_at

  json.boat_class do
    json.extract! race.boat_class, :name, :is_one_design
  end

  json.recordings race.cached_recording_ids do |recording_id|
    json.partial! 'recordings/recording', recording: Recording.find(recording_id)
  end
end

json.url race_url(race, format: :json)
