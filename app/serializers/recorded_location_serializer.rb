class RecordedLocationSerializer < ActiveModel::Serializer
  attributes :id, :latitude, :longitude, :adjusted_latitude, :adjusted_longitude, :accuracy, :created_at, :recorded_at
  belongs_to :recording
end
