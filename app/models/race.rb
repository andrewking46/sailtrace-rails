class Race < ApplicationRecord
  include Geocodable

  belongs_to :boat_class, optional: true
  has_many :recordings

  validates :started_at, :start_latitude, :start_longitude, presence: true

  scope :empty, -> { left_joins(:recordings).where(recordings: { id: nil }) }

  after_commit :invalidate_cache, on: %i[update destroy]

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

  def invalidate_cache
    CacheManager.delete("#{cache_key}/json")
    CacheManager.delete("#{cache_key}/recording_ids")
  end

  def cached_recording_ids
    CacheManager.fetch("#{cache_key}/recording_ids") do
      recordings.pluck(:id)
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
