# frozen_string_literal: true

# A minimal JSON for the web's Recording "show" endpoint.
# We do NOT embed thousands of RecordedLocation records here.
# Instead, call /recordings/:id/recorded_locations to fetch
# the cached, compressed data separately.

json.extract! recording,
  :id,
  :name,
  :started_at,
  :ended_at,
  :time_zone,
  :start_latitude,
  :start_longitude,
  :wind_direction_degrees,
  :wind_direction_cardinal,
  :wind_speed,
  :is_race,
  :created_at,
  :updated_at

json.boat do
  json.extract! recording.boat,
    :name,
    :registration_country,
    :sail_number,
    :hull_color
end

json.url my_recording_url(recording, format: :json)
