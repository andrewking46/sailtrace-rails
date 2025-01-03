# frozen_string_literal: true

module Races
  # AssociationService is responsible for deciding whether a Recording
  # belongs to an existing Race or if we should create a new Race.
  #
  # The "ultimate" approach below:
  # 1. Filters potential races by time and distance.
  # 2. Prefers the Race with the closest start coordinate to the Recording.
  # 3. Fallbacks to creating a new Race if none match.
  #
  # This logic aims to:
  # - Minimize false negatives by catching all Races within our thresholds.
  # - Minimize false positives by carefully picking the closest Race.
  # - Remain simple and memory-efficient by leveraging standard ActiveRecord
  #   queries and geospatial indexing from Geocoder.
  class AssociationService
    TIME_WINDOW          = 10.minutes
    DISTANCE_THRESHOLD_KM = 0.75  # 0.75 km radius for Race "start line"

    def initialize(recording)
      @recording = recording
    end

    # Public: Main entry point for race association.
    # Returns nothing. Associates the @recording with an existing or new Race.
    def associate
      # 1) Ensure we have lat/lon to make geospatial queries feasible.
      return unless valid_for_association?

      # 2) Attempt to find the best Race match or create a new one.
      race = find_best_race_or_create

      # 3) Link this recording to the chosen race, then finalize.
      @recording.update!(race:)
      race.finalize
    end

    private

    # We only proceed if the recording has a valid start location.
    def valid_for_association?
      @recording.start_latitude.present? && @recording.start_longitude.present?
    end

    # Finds all potential Races that:
    #  - started within +/- TIME_WINDOW of the recording's start time
    #  - are near the recording start coordinate (within DISTANCE_THRESHOLD_KM)
    #  - share the boat_class_id (or have none set)
    # Returns the single best Race or creates a new one.
    def find_best_race_or_create
      potential_races = Race
        .where(started_at: time_range)
        .where(boat_class_id: [ nil, @recording.boat.boat_class_id ])
        .near(
          [ @recording.start_latitude, @recording.start_longitude ],
          DISTANCE_THRESHOLD_KM,
          units: :km
        )

      # Among the candidates, pick the race whose start coordinate
      # is geodesically closest to the recording’s start coordinate.
      best_race = potential_races.min_by do |race|
        Gps::DistanceCalculator.distance_in_meters(
          race.start_latitude.to_f,
          race.start_longitude.to_f,
          @recording.start_latitude.to_f,
          @recording.start_longitude.to_f
        )
      end

      # If no suitable Race is found, create one using the
      # essential attributes from the Recording.
      best_race || Race.create!(race_attributes)
    end

    # Defines an acceptable window for Race start time.
    # e.g. if the Recording started at 10:00, we look for Races
    # from 9:50 to 10:10
    def time_range
      (@recording.started_at - TIME_WINDOW)..(@recording.started_at + TIME_WINDOW)
    end

    # Provides the attributes needed to create a new Race
    # from the Recording if no matching Race is found.
    def race_attributes
      {
        started_at:      @recording.started_at,
        start_latitude:  @recording.start_latitude,
        start_longitude: @recording.start_longitude,
        boat_class_id:   @recording.boat.boat_class_id
      }
    end
  end
end
