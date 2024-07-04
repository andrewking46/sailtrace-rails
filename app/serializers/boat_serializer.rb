class BoatSerializer < ActiveModel::Serializer
  attributes :id, :name, :registration_country, :sail_number, :hull_color
  belongs_to :boat_class
  belongs_to :user
end
