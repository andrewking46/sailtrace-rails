# frozen_string_literal: true

# File: app/views/races/show.json.jbuilder
#

json.extract! @race,
  :id,
  :name,
  :started_at,
  :start_latitude,
  :start_longitude,
  :created_at

if @race.boat_class
  json.boat_class do
    json.extract! @race.boat_class,
      :id,
      :name,
      :is_one_design
  end
end

# Return the minimal data for each recording
json.recordings @race.recordings do |recording|
  json.extract! recording,
    :id,
    :started_at,
    :ended_at,
    :wind_direction_degrees,
    :wind_direction_cardinal,
    :wind_speed

  json.boat do
    json.extract! recording.boat, :id, :name, :registration_country, :sail_number, :hull_color
  end
end

json.url race_url(@race, format: :json)
