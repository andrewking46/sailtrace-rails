module Races
  class AssociationService
    TIME_WINDOW = 5.minutes
    DISTANCE_THRESHOLD = 0.5 # km

    def initialize(recording)
      @recording = recording
    end

    def associate
      return unless @recording.start_latitude && @recording.start_longitude

      race = find_or_create_race
      @recording.update(race:)
      race.finalize
    end

    private

    def find_or_create_race
      Race.near([ @recording.start_latitude, @recording.start_longitude ], DISTANCE_THRESHOLD, units: :km)
          .where(started_at: time_range)
          .first_or_create(race_attributes)
    end

    def time_range
      (@recording.started_at - TIME_WINDOW)..(@recording.started_at + TIME_WINDOW)
    end

    def race_attributes
      {
        started_at: @recording.started_at,
        start_latitude: @recording.start_latitude,
        start_longitude: @recording.start_longitude,
        boat_class_id: @recording.boat.boat_class_id
      }
    end
  end
end
