class Recording < ApplicationRecord
  include Geocodable
  include Durationable

  belongs_to :boat
  belongs_to :user, default: -> { Current.user }
  belongs_to :race, optional: true
  has_many :recorded_locations, dependent: :destroy

  validates :started_at, :time_zone, :boat_id, :user_id, presence: true
  validate :end_after_start

  before_validation :set_started_at, on: :create
  after_update :process_ending, if: :saved_change_to_ended_at?
  after_destroy :cleanup_race

  scope :in_progress, -> { where(ended_at: nil).where.not(started_at: nil) }

  def end!
    update!(ended_at: Time.current)
  end

  def ended?
    ended_at.present?
  end

  def calculate_distance
    distance || Recordings::DistanceCalculationService.new(self).calculate
  end

  def average_speed
    return 0 if duration_seconds.zero? || calculate_distance.zero?
    (calculate_distance / (duration_seconds / 3600.0)).round(2)
  end

  def status
    return :not_started if started_at.nil?
    return :in_progress if ended_at.nil?
    return :processing if last_processed_at.nil?
    :processed
  end

  private

  def set_started_at
    self.started_at ||= Time.current
  end

  def process_ending
    return unless ended?
    set_start_location
    result = Recordings::ProcessorService.new(self).process
    update(last_processed_at: Time.current)
    # RecordingProcessorJob.perform_later(id)
  end

  def cleanup_race
    race&.destroy_if_empty if is_race?
  end

  def end_after_start
    errors.add(:ended_at, "must be after the start time") if ended? && ended_at < started_at
  end

  def set_start_location
    return if start_latitude.present? && start_longitude.present?
    first_recorded_location = recorded_locations.order(created_at: :asc).first
    update(start_latitude: first_recorded_location.latitude, start_longitude: first_recorded_location.longitude) unless first_recorded_location.blank?
  end
end
