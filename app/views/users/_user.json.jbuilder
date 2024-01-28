json.extract! user, :id, :username, :first_name, :last_name, :email_address, :phone_number, :country, :time_zone, :date_of_birth, :is_admin, :created_at, :updated_at
json.url user_url(user, format: :json)
