class RecordingSerializer < ActiveModel::Serializer
  attributes :id, :name, :started_at, :ended_at, :time_zone, :is_race, :start_latitude, :start_longitude, :distance
  belongs_to :boat
  belongs_to :user
  belongs_to :race, optional: true

  def boat
    BoatSerializer.new(object.boat).as_json
  end

  def cache_key
    object.cache_key
  end
end
