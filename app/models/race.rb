class Race < ApplicationRecord
  belongs_to :boat_class, optional: true
  has_many :recordings

  validates :started_at, :start_latitude, :start_longitude, presence: true

  reverse_geocoded_by :start_latitude, :start_longitude

  def after_ending_actions
    recalculate_start_attributes
    update_boat_class_if_consistent
  end

  def recalculate_start_attributes
    puts "recalculate_start_attributes"
    return unless recordings.count > 1
    self.started_at = recordings.minimum(:started_at)
    self.start_latitude = recordings.average(:start_latitude)
    self.start_longitude = recordings.average(:start_longitude)
    save
  end

  def update_boat_class_if_consistent
    puts "update_boat_class_if_consistent"
    return unless recordings.count > 1
    boat_classes = recordings.joins(:boat).pluck('boats.boat_class_id').compact.uniq

    self.boat_class_id = boat_classes.size == 1 ? boat_classes.first : nil
    save if boat_class_id_changed?
  end

  def destroy_if_recordings_empty
    puts "destroy_if_recordings_empty"
    destroy if recordings.count.zero?
  end
end
