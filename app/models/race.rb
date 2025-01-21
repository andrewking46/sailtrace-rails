# frozen_string_literal: true

class Race < ApplicationRecord
  include Geocodable

  belongs_to :boat_class, optional: true
  has_many :recordings
  has_many :course_marks, dependent: :destroy

  validates :started_at, :start_latitude, :start_longitude, presence: true

  scope :empty, -> { left_joins(:recordings).where(recordings: { id: nil }) }

  def ended_at
    recordings.maximum(:ended_at)
  end

  def finalize
    recalculate_attributes
    update_boat_class
  end

  def destroy_if_empty
    destroy if recordings.empty?
  end

  def time_zone
    CacheManager.fetch("#{cache_key}/time_zone") do
      time_zone_counts = recordings.group(:time_zone).count
      if time_zone_counts.any?
        time_zone_counts.max_by { |_time_zone, count| count }&.first
      else
        nil
      end
    end
  end

  def wind_direction_degrees
    CacheManager.fetch("#{cache_key}/wind_direction_degrees") do
      recordings.where.not(wind_direction_degrees: nil).average(:wind_direction_degrees).to_f.round
    end
  end

  def wind_direction_cardinal
    CacheManager.fetch("#{cache_key}/wind_direction_cardinal") do
      directions = [ "N", "NE", "E", "SE", "S", "SW", "W", "NW" ]
      idx = ((wind_direction_degrees + 22.5) / 45).floor % 8
      directions[idx]
    end
  end

  def wind_speed
    CacheManager.fetch("#{cache_key}/wind_speed") do
      recordings.where.not(wind_speed: nil).average(:wind_speed).to_f.round(2)
    end
  end

  private

  def recalculate_attributes
    return if recordings.count <= 1

    update(
      started_at: recordings.minimum(:started_at),
      start_latitude: recordings.average(:start_latitude),
      start_longitude: recordings.average(:start_longitude)
    )
  end

  def update_boat_class
    return if recordings.count < 3

    boat_class_ids = recordings
                     .joins(:boat)
                     .distinct
                     .pluck("boats.boat_class_id")
                     .compact

    if boat_class_ids.size == 1
      update(boat_class_id: boat_class_ids.first)
    else
      update(boat_class_id: nil)
    end
  end
end
