# app/models/maneuver.rb
# frozen_string_literal: true

class Maneuver < ApplicationRecord
  belongs_to :recording

  # If you prefer a real enum approach:
  # enum maneuver_type: {
  #   tack:         "tack",
  #   jibe:         "jibe",
  #   rounding:     "rounding",
  #   penalty_spin: "penalty_spin",
  #   unknown:      "unknown"
  # }, _prefix: :maneuver

  validates :recording_id, presence: true
  validates :cumulative_heading_change, numericality: { greater_than_or_equal_to: -720, less_than_or_equal_to: 720 }
  validates :latitude, :longitude, presence: true
  validates :occurred_at, presence: true
  validates :maneuver_type, presence: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0 }

  # If needed, define scopes for common queries:
  # scope :big_roundings, -> { where("cumulative_heading_change >= 80 OR cumulative_heading_change <= -80") }
end
