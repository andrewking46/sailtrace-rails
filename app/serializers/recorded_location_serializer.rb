class RecordedLocationSerializer < ActiveModel::Serializer
  attributes :id, :latitude, :longitude, :velocity, :heading, :accuracy, :created_at
  belongs_to :recording
end
