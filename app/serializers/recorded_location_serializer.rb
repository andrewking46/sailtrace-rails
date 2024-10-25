# frozen_string_literal: true

class RecordedLocationSerializer < ActiveModel::Serializer
  attributes :id, :recording_id, :adjusted_latitude, :adjusted_longitude, :velocity, :heading, :recorded_at
end
