class UserSerializer < ActiveModel::Serializer
  attributes :id, :username, :first_name, :last_name, :email_address, :phone_number, :country, :time_zone, :created_at
end
