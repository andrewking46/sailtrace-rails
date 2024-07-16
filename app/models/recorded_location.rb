class RecordedLocation < ApplicationRecord
  belongs_to :recording

  validates :latitude, :longitude, presence: true
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :heading, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 360 }, allow_blank: true
  validates :adjusted_latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_blank: true
  validates :adjusted_longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_blank: true
end
