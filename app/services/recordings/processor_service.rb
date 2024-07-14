module Recordings
  class ProcessorService
    def initialize(recording)
      @recording = recording
    end

    def process
      Rails.logger.info "Starting processing for Recording #{@recording.id}"
      ApplicationRecord.transaction do
        process_locations
        calculate_statistics
        associate_with_race if @recording.is_race?
      end
      Rails.logger.info "Completed processing for Recording #{@recording.id}"
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      Rails.logger.error "Database error in ProcessorService: #{e.message}\n#{e.backtrace.join("\n")}"
      ErrorNotifierService.notify(e, context: { recording_id: @recording.id, error_type: 'database_error' })
      raise
    rescue StandardError => e
      Rails.logger.error "Unexpected error in ProcessorService: #{e.message}\n#{e.backtrace.join("\n")}"
      ErrorNotifierService.notify(e, context: { recording_id: @recording.id, error_type: 'unexpected_error' })
      raise
    end

    def process_locations
      Rails.logger.info "Processing locations for recording #{@recording.id}"
      LocationProcessorService.new(@recording).process
      # optimize_gps_data
    end

    def optimize_gps_data
      Rails.logger.info "Optimizing GPS data for recording #{@recording.id}"
      locations = @recording.recorded_locations.select(:adjusted_latitude, :adjusted_longitude, :accuracy, :created_at).order(:created_at)
      processed_locations = Gps::DataProcessingService.new(locations).process
      update_locations(processed_locations)
    end

    def calculate_statistics
      Rails.logger.info "Calculating statistics for recording #{@recording.id}"
      distance = @recording.calculate_distance
      @recording.update(distance: distance)
    end

    def associate_with_race
      Rails.logger.info "Associating with race for recording #{@recording.id}"
      Races::AssociationService.new(@recording).associate if @recording.is_race?
    end

    private

    def update_locations(processed_locations)
      RecordedLocation.transaction do
        @recording.recorded_locations.order(:created_at).each_with_index do |location, index|
          location.update(
            adjusted_latitude: processed_locations[index][:latitude],
            adjusted_longitude: processed_locations[index][:longitude]
          )
        end
      end
    end
  end
end
