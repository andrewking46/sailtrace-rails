json.extract! boat, :id, :name, :registration_country, :sail_number, :hull_color, :boat_class_id, :user_id,
              :created_at, :updated_at
json.url my_boat_url(boat, format: :json)
