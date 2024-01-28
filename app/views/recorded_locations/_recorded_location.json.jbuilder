json.extract! recorded_location, :id, :latitude, :longitude, :velocity, :heading, :recording_id, :created_at, :updated_at
json.url recorded_location_url(recorded_location, format: :json)
