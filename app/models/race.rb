class Race < ApplicationRecord
  include Geocodable

  belongs_to :boat_class, optional: true
  has_many :recordings

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
    return if recordings.count <= 1

    consistent_boat_class = recordings.joins(:boat)
                                      .select('boats.boat_class_id')
                                      .distinct
                                      .having('COUNT(DISTINCT boats.boat_class_id) = 1')
                                      .pluck('boats.boat_class_id')
                                      .first

    update(boat_class_id: consistent_boat_class)
  end
end
