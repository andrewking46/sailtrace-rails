# app/models/course_mark.rb
# frozen_string_literal: true

class CourseMark < ApplicationRecord
  belongs_to :race

  validates :race_id, :latitude, :longitude, presence: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0 }
  validates :mark_type, presence: true

  # Example scope:
  # scope :high_confidence, -> { where("confidence >= 0.8") }
end
