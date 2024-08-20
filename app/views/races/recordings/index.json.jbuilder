json.array!(@recordings) do |recording|
  json.extract! recording, :id, :started_at, :ended_at, :time_zone, :is_race, :created_at

  json.boat do
    json.extract! recording.boat, :name, :registration_country, :sail_number, :hull_color
  end

  json.recorded_locations recording.recorded_locations.order(:recorded_at) do |recorded_location|
    json.extract! recorded_location, :id, :latitude, :longitude, :created_at, :recorded_at, :adjusted_latitude,
                  :adjusted_longitude
  end
end
