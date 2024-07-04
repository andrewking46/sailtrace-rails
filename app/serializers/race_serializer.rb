class RaceSerializer < ActiveModel::Serializer
  attributes :id, :name, :started_at, :start_latitude, :start_longitude
  belongs_to :boat_class
end
