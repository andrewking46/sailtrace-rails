module Recordings
  class ProcessorService
    def initialize(recording)
      @recording = recording
    end

    def process
      ApplicationRecord.transaction do
        process_locations
        calculate_statistics
        associate_with_race if @recording.is_race?
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      ErrorNotifierService.notify(e, context: { recording_id: @recording.id, error_type: 'database_error' })
      raise
    rescue StandardError => e
      ErrorNotifierService.notify(e, context: { recording_id: @recording.id, error_type: 'unexpected_error' })
      raise
    end

    def process_locations
      LocationProcessorService.new(@recording).process
      # optimize_gps_data
    end

    def optimize_gps_data
      locations = @recording.recorded_locations.select(:adjusted_latitude, :adjusted_longitude, :accuracy, :created_at, :recorded_at).order(:recorded_at)
      processed_locations = Gps::DataProcessingService.new(locations).process
      update_locations(processed_locations)
    end

    def calculate_statistics
      distance = @recording.calculate_distance
      @recording.update(distance: distance)
    end

    def associate_with_race
      Races::AssociationService.new(@recording).associate if @recording.is_race?
    end

    private

    def update_locations(processed_locations)
      RecordedLocation.transaction do
        @recording.recorded_locations.order(:recorded_at).each_with_index do |location, index|
          location.update(
            adjusted_latitude: processed_locations[index][:latitude],
            adjusted_longitude: processed_locations[index][:longitude]
          )
        end
      end
    end
  end
end
