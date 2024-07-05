class RecordingManagerService
  def initialize(recording)
    @recording = recording
  end

  def process
    ActiveRecord::Base.transaction do
      process_locations
      calculate_statistics
      associate_with_race if @recording.is_race?
    end
  rescue StandardError => e
    Rails.logger.error "Error processing recording #{@recording.id}: #{e.message}"
    ErrorNotifierService.notify(e, context: { recording_id: @recording.id })
    raise
  end

  private

  def process_locations
    RecordingLocationProcessorService.new(@recording).process
    optimize_gps_data
  end

  def optimize_gps_data
    locations = @recording.recorded_locations.order(created_at: :asc).pluck(:adjusted_latitude, :adjusted_longitude, :accuracy, :created_at)
    attributes = %i[latitude longitude accuracy created_at]
    processed_locations = GpsDataProcessingService.new(locations.map { |l| attributes.zip(l).to_h }).process

    update_locations(processed_locations)
  end

  def update_locations(processed_locations)
    RecordedLocation.transaction do
      @recording.recorded_locations.order(created_at: :asc).each_with_index do |location, index|
        location.update(
          adjusted_latitude: processed_locations[index][:latitude],
          adjusted_longitude: processed_locations[index][:longitude]
        )
      end
    end
  end

  def calculate_statistics
    @recording.update(
      distance: @recording.distance,
      average_speed: @recording.average_speed
    )
  end

  def associate_with_race
    RaceAssociationService.new(@recording).associate
  end
end
