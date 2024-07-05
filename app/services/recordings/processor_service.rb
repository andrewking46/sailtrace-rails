module Recordings
  class ProcessorService
    def initialize(recording)
      @recording = recording
    end

    def process_locations
      Rails.logger.info "Processing locations for recording #{@recording.id}"
      LocationProcessorService.new(@recording).process
    end

    def optimize_gps_data
      Rails.logger.info "Optimizing GPS data for recording #{@recording.id}"
      locations = @recording.recorded_locations.order(:created_at).pluck(:adjusted_latitude, :adjusted_longitude, :accuracy, :created_at)
      processed_locations = Gps::DataProcessingService.new(locations).process
      update_locations(processed_locations)
    end

    def calculate_statistics
      Rails.logger.info "Calculating statistics for recording #{@recording.id}"
      distance = @recording.calculate_distance
      average_speed = @recording.average_speed
      Rails.logger.info "Recording #{@recording.id} statistics: Distance: #{distance}, Average Speed: #{average_speed}"
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
