json.extract! race, :id, :name, :started_at, :start_latitude, :start_longitude, :created_at

json.boat_class do
  json.extract! race.boat_class, :name, :is_one_design
end

json.recordings race.recordings do |recording|
  json.extract! recording, :id, :started_at, :ended_at, :time_zone, :created_at

  json.boat do
    json.extract! recording.boat, :name, :registration_country, :sail_number, :hull_color
  end

  json.recorded_locations recording.recorded_locations.order(:created_at) do |recorded_location|
    json.extract! recorded_location, :id, :latitude, :longitude, :adjusted_latitude, :adjusted_longitude, :accuracy, :created_at
  end
end

json.url race_url(race, format: :json)
