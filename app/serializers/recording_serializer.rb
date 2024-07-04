class RecordingSerializer < ActiveModel::Serializer
  attributes :id, :name, :started_at, :ended_at, :time_zone, :is_race, :start_latitude, :start_longitude
  belongs_to :boat
  belongs_to :user
  belongs_to :race, optional: true
end
