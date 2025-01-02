# frozen_string_literal: true

module Recordings
  # SimplificationService orchestrates the Visvalingam-Whyatt simplification
  # across a Recording's RecordedLocations in manageable chunks to ensure
  # memory efficiency.
  class SimplificationService
    # Defines the number of points per chunk and overlap size.
    CHUNK_SIZE = 200
    OVERLAP_SIZE = 2
    TARGET_PERCENTAGE = 0.4 # Target to eliminate 50% of points.

    # Initialize with a specific Recording instance.
    #
    # @param recording [Recording] The recording to simplify.
    def initialize(recording)
      @recording = recording
    end

    # Executes the simplification process.
    #
    # @return [void]
    def process
      # Reset any previous simplifications to start fresh.
      reset_simplifications

      # Calculate total points and target reduction.
      total_points = @recording.recorded_locations.count
      target_size = (total_points * TARGET_PERCENTAGE).ceil

      # Early exit conditions.
      return if target_size >= total_points || total_points <= 2

      # Fetch all recorded_locations ordered chronologically.
      locations = @recording.recorded_locations.order(:recorded_at).pluck(:adjusted_latitude, :adjusted_longitude, :id)

      # Process in overlapping chunks.
      simplified_ids = []
      (0...locations.size).step(CHUNK_SIZE) do |start_index|
        # Determine the end index with overlap.
        end_index = [start_index + CHUNK_SIZE + OVERLAP_SIZE, locations.size].min
        chunk = locations[start_index...end_index]

        # Ensure the chunk has enough points to simplify (at least 3)
        next if chunk.size < 3

        # Apply Visvalingam-Whyatt on the current chunk.
        chunk_simplified_ids = simplify_chunk(chunk, target_size - simplified_ids.size)

        # Accumulate simplified point IDs.
        simplified_ids.concat(chunk_simplified_ids)

        # Break if target size is met.
        break if simplified_ids.size >= target_size
      end

      # Mark the simplified points in the database.
      mark_simplified_points(simplified_ids)

      # Log the simplification outcome.
      log_simplification_results
    end

    private

    # Resets all RecordedLocations to unsimplified before starting.
    #
    # @return [void]
    def reset_simplifications
      @recording.recorded_locations.update_all(is_simplified: false)
    end

    # Applies the VW algorithm to a chunk and returns simplified point IDs.
    #
    # @param chunk [Array<Array<Float, Float, Integer>>] Array of [latitude, longitude, id].
    # @param remaining [Integer] Number of points left to simplify.
    # @return [Array<Integer>] IDs of simplified points.
    def simplify_chunk(chunk, remaining)
      # Convert chunk into point hashes.
      points = chunk.map { |lat, lng, id| { latitude: lat, longitude: lng, id: id } }

      # Initialize the VW algorithm with the points.
      vw = Gps::VisvalingamWhyatt.new(points, target_reduction: calculate_chunk_reduction(chunk.size, remaining))
      simplified_points = vw.simplify

      # Extract IDs of points to simplify (those not in simplified_points).
      # These are the points that were removed by the algorithm.
      simplified_ids = chunk.map { |_, _, id| id } - simplified_points.map { |p| p[:id] }

      # Limit the number of points to not exceed the remaining target.
      simplified_ids.first([simplified_ids.size, remaining].min)
    end

    # Calculates the reduction percentage for a chunk based on remaining simplifications.
    #
    # @param chunk_size [Integer] Number of points in the current chunk.
    # @param remaining [Integer] Points left to simplify.
    # @return [Float] Reduction percentage for the chunk.
    def calculate_chunk_reduction(chunk_size, remaining)
      return 0.0 if remaining <= 0

      # Determine the reduction needed in this chunk without exceeding the remaining target.
      reduction = [remaining.to_f / chunk_size, TARGET_PERCENTAGE].min  # Limit to the same target percentage per chunk for consistency.
      reduction
    end

    # Marks the given point IDs as simplified in the database.
    #
    # @param simplified_ids [Array<Integer>] IDs of points to mark as simplified.
    # @return [void]
    def mark_simplified_points(simplified_ids)
      return if simplified_ids.empty?

      RecordedLocation.where(id: simplified_ids).update_all(is_simplified: true)
    end

    # Logs the simplification process details.
    #
    # @return [void]
    def log_simplification_results
      original_count = @recording.recorded_locations.count
      simplified_count = @recording.recorded_locations.where(is_simplified: true).count
      remaining_count = original_count - simplified_count
      Rails.logger.info "Simplified #{original_count} points down to #{remaining_count} points."
    end
  end
end
