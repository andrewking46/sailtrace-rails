# app/serializers/maneuver_serializer.rb
# frozen_string_literal: true

class ManeuverSerializer < ActiveModel::Serializer
  attributes :id,
             :recording_id,
             :cumulative_heading_change,
             :latitude,
             :longitude,
             :occurred_at,
             :maneuver_type,
             :confidence
end
