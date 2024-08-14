class RecordedLocationSerializer < ActiveModel::Serializer
  attributes :id, :recording_id, :adjusted_latitude, :adjusted_longitude, :accuracy, :recorded_at
end
