# app/serializers/course_mark_serializer.rb
# frozen_string_literal: true

class CourseMarkSerializer < ActiveModel::Serializer
  attributes :id,
             :race_id,
             :latitude,
             :longitude,
             :mark_type,
             :confidence
end
