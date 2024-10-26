# frozen_string_literal: true

module Recordings
  # VelocityHeadingService calculates and stores smoothed velocity and heading data
  # for GPS tracks. It processes recorded locations in batches and uses a sliding
  # window approach for speed calculations to reduce noise in the data.
  #
  # Performance optimizations:
  # - Processes locations in batches to minimize database calls
  # - Uses bulk updates instead of individual updates
  # - Preallocates arrays for batch processing
  # - Uses SQL select to load only required fields
  class VelocityHeadingService
    # Size of the sliding window for speed calculations
    WINDOW_SIZE = 10

    # Number of locations to process in each batch
    BATCH_SIZE = 100

    # Minimum time difference between points to consider for velocity
    MIN_TIME_DIFF = 0.5

    # Maximum reasonable velocity in knots for outlier detection
    MAX_VELOCITY = 15.0

    # Initialize the service with a recording
    # @param recording [Recording] The recording to process
    def initialize(recording)
      @recording = recording
      @speed_calculator = Gps::SmoothedSpeedCalculator.new(
        window_size: WINDOW_SIZE,
        output_knots: false
      )
    end

    # Process all non-simplified locations in the recording
    # @return [void]
    def process
      previous_location = nil
      updates = []

      # Process locations in batches, selecting only required fields
      @recording.recorded_locations
                .not_simplified
                .chronological
                .select(:id, :recording_id, :latitude, :longitude, :adjusted_latitude, :adjusted_longitude, :recorded_at)
                .find_in_batches(batch_size: BATCH_SIZE) do |batch|
        process_batch(batch, previous_location, updates)
        previous_location = batch.last
      end
    ensure
      # Ensure calculator state is reset after processing
      @speed_calculator.reset
    end

    private

    # Process a batch of locations
    # @param batch [Array<RecordedLocation>] Batch of locations to process
    # @param previous_location [RecordedLocation, nil] Last location from previous batch
    # @param updates [Array<Hash>] Array to collect update operations
    # @return [void]
    def process_batch(batch, previous_location, updates)
      batch.each do |location|
        if result = process_location(location, previous_location)
          updates << result
        end
        previous_location = location
      end

      # Perform bulk update if we have any updates
      bulk_update(updates) if updates.any?
      updates.clear  # Clear array for reuse
    end

    # Process a single location
    # @param location [RecordedLocation] Current location
    # @param previous_location [RecordedLocation, nil] Previous location
    # @return [Hash, nil] Update attributes or nil if processing not possible
    def process_location(location, previous_location)
      return nil unless previous_location

      time_diff = (location.recorded_at - previous_location.recorded_at).to_f
      return nil if time_diff < MIN_TIME_DIFF

      velocity = calculate_velocity(previous_location, location, time_diff)
      return nil if velocity > MAX_VELOCITY  # Skip outliers

      heading = calculate_heading(previous_location, location)

      {
        id: location.id,
        recording_id: location.recording_id,
        latitude: location.latitude,
        longitude: location.longitude,
        velocity: velocity.round(2),
        heading: heading
      }
    end

    # Calculate smoothed velocity between two points
    # @param prev_loc [RecordedLocation] Previous location
    # @param curr_loc [RecordedLocation] Current location
    # @param time_diff [Float] Time difference in seconds
    # @return [Float] Smoothed velocity in knots
    def calculate_velocity(prev_loc, curr_loc, time_diff)
      @speed_calculator.add_point(
        prev_loc.adjusted_latitude,
        prev_loc.adjusted_longitude,
        curr_loc.adjusted_latitude,
        curr_loc.adjusted_longitude,
        time_diff
      )
    end

    # Calculate heading between two points
    # @param prev_loc [RecordedLocation] Previous location
    # @param curr_loc [RecordedLocation] Current location
    # @return [Float] Heading in degrees (0-360)
    def calculate_heading(prev_loc, curr_loc)
      Gps::HeadingCalculator.calculate(prev_loc, curr_loc)
    end

    # Perform bulk update of locations
    # @param updates [Array<Hash>] Array of updates to apply
    # @return [void]
    def bulk_update(updates)
      RecordedLocation.upsert_all(
        updates,
        unique_by: :id,
        update_only: [ :velocity, :heading ],
        returning: false
      )
    end
  end
end
