# frozen_string_literal: true

module Recordings
  # KalmanFilterService applies a Kalman filter to smooth GPS data for a recording
  class KalmanFilterService
    # Process locations in batches to optimize memory usage
    BATCH_SIZE = 100

    # Size of the sliding window for speed calculations
    WINDOW_SIZE = 10

    def initialize(recording)
      @recording = recording
      @filter = Gps::KalmanFilter.new
      @speed_calculator = Gps::SmoothedSpeedCalculator.new(
        window_size: WINDOW_SIZE,
        output_knots: false
      )
    end

    # Process all locations in the recording
    def process
      previous_location = nil

      # Process locations in batches
      @recording.recorded_locations.chronological.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        updates = process_batch(batch, previous_location)

        # Perform bulk update to improve database performance
        bulk_update(updates)

        # Update previous_location for the next batch
        previous_location = batch.last
      end
    end

    private

    # Process a batch of locations
    # @param batch [Array<RecordedLocation>] Batch of locations to process
    # @param previous_location [RecordedLocation, nil] Last location from previous batch
    # @return [Array<Hash>] Updates to be applied to the database
    def process_batch(batch, previous_location)
      batch.each_with_object([]) do |location, updates|
        speed = calculate_speed(previous_location, location)

        filtered_coords = @filter.update(
          location.latitude,
          location.longitude,
          location.accuracy,
          location.recorded_at.to_f,
          speed
        )

        if filtered_coords
          updates << {
            id: location.id,
            recording_id: location.recording_id,
            latitude: location.latitude,
            longitude: location.longitude,
            adjusted_latitude: filtered_coords[:lat],
            adjusted_longitude: filtered_coords[:lng]
          }
        end

        previous_location = location
      end
    end

    # Calculate speed between two locations
    # @param prev_loc [RecordedLocation, nil] Previous location
    # @param curr_loc [RecordedLocation] Current location
    # @return [Float] Calculated speed in meters per second
    def calculate_speed(prev_loc, curr_loc)
      return 0 unless prev_loc

      @speed_calculator.add_point(
        prev_loc.latitude, prev_loc.longitude,
        curr_loc.latitude, curr_loc.longitude,
        (curr_loc.recorded_at - prev_loc.recorded_at).to_f
      )
    end

    # Perform bulk update of locations
    # @param updates [Array<Hash>] Updates to be applied
    def bulk_update(updates)
      RecordedLocation.upsert_all(
        updates,
        unique_by: :id,
        update_only: %i[adjusted_latitude adjusted_longitude],
        returning: false
      )
    end
  end
end
