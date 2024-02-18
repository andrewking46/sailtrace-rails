class Recording < ApplicationRecord
  belongs_to :boat
  belongs_to :user
  belongs_to :race, optional: true
  has_many :recorded_locations, dependent: :destroy

  validates :started_at, :time_zone, :boat_id, :user_id, presence: true
  validate :end_after_start

  before_validation :set_started_at_value, on: :create
  after_update_commit :after_ending_actions, if: :just_ended?
  after_destroy_commit :destroy_race_if_no_recordings

  reverse_geocoded_by :start_latitude, :start_longitude

  def started?
    started_at.present?
  end

  def in_progress?
    started? && !ended?
  end

  def just_ended?
    puts saved_change_to_ended_at?
    puts ended?
    saved_change_to_ended_at? && ended?
  end

  def ended?
    ended_at.present?
  end

  def end!
    self.ended_at = DateTime.current
    save!
  end

  def average_speed
    total_seconds = duration_in_seconds
    return 0 if total_seconds.zero?

    hours = total_seconds / 3600.0
    (distance / hours).round(2)
  end

  def distance
    total_distance = 0
    recorded_locations.order(created_at: :asc).each_cons(2) do |loc1, loc2|
      total_distance += distance_between(loc1, loc2)
    end
    total_distance.round(5)
  end

  def duration
    return "00:00:00" unless ended? && started?

    total_seconds = duration_in_seconds
    hours = total_seconds / 3600
    minutes = (total_seconds / 60) % 60
    seconds = total_seconds % 60

    format("%02d:%02d:%02d", hours, minutes, seconds)
  end

  def duration_in_seconds
    return 0 unless ended? && started?
    (ended_at - started_at).to_i
  end

  private

  def distance_between(loc1, loc2)
    # Haversine formula to calculate the distance between two points on the Earth
    # Convert latitude and longitude from degrees to radians
    rad_per_deg = Math::PI / 180
    rkm = 6371              # Earth radius in kilometers
    rm = rkm * 0.539956803  # Radius in nautical miles
    dlat_rad = (loc2.latitude - loc1.latitude) * rad_per_deg
    dlon_rad = (loc2.longitude - loc1.longitude) * rad_per_deg

    lat1_rad = loc1.latitude * rad_per_deg
    lat2_rad = loc2.latitude * rad_per_deg

    a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    rm * c # Delta in nautical miles
  end

  def set_started_at_value
    self.started_at = DateTime.current
  end

  def after_ending_actions
    puts "after_ending_actions called"
    set_start_location_values
    associate_with_race
  end

  def set_start_location_values
    puts "set_start_location_values called"
    return if start_latitude.present? || start_longitude.present?
    first_recorded_location = recorded_locations.order(created_at: :asc).first
    self.start_latitude = first_recorded_location.latitude
    self.start_longitude = first_recorded_location.longitude
    save
    puts "set_start_location_values saved"
  end

  def end_after_start
    errors.add(:ended_at, "Must be after the start time") if ended? && started? && ended_at < started_at
  end

  def associate_with_race
    puts "associate_with_race called"
    return unless is_race?

    time_window = 5.minutes

    # Use Geocoder's 'near' scope to find races within distance_threshold of the recording's start location
    nearby_races = Race.near([start_latitude, start_longitude], 0.5, units: :km)
                       .where(started_at: started_at - time_window..started_at + time_window)

    self.race = nearby_races.first || Race.create!(
      started_at: started_at,
      start_latitude: start_latitude,
      start_longitude: start_longitude,
      boat_class_id: boat.boat_class_id
    )

    save
    race.after_ending_actions
    puts "associate_with_race saved"
  end

  def destroy_race_if_no_recordings
    return unless is_race? and race.present?
    race.destroy_if_recordings_empty
  end
end
