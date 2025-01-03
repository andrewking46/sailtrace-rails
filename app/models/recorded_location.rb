# frozen_string_literal: true

class RecordedLocation < ApplicationRecord
  belongs_to :recording

  scope :not_simplified, -> { where(is_simplified: false) }
  scope :chronological, -> { order(:recorded_at) }
  scope :processed, -> { where.not(heading: nil, velocity: nil, adjusted_latitude: nil, adjusted_longitude: nil) }

  validates :latitude, :longitude, :recorded_at, presence: true
  validates :latitude, numericality: { greater_than_or_equal_to: -90.0, less_than_or_equal_to: 90.0 }
  validates :longitude, numericality: { greater_than_or_equal_to: -180.0, less_than_or_equal_to: 180.0 }
  validates :velocity, numericality: { greater_than_or_equal_to: 0.0 }, allow_blank: true
  validates :heading, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 360.0 }, allow_blank: true
  validates :adjusted_latitude, numericality: { greater_than_or_equal_to: -90.0, less_than_or_equal_to: 90.0 },
                                allow_blank: true
  validates :adjusted_longitude, numericality: { greater_than_or_equal_to: -180.0, less_than_or_equal_to: 180.0 },
                                 allow_blank: true

  validate :recorded_at_not_in_future

  private

  def recorded_at_not_in_future
    return unless recorded_at.present? && recorded_at > Time.current

    errors.add(:recorded_at, "can't be in the future")
  end
end
