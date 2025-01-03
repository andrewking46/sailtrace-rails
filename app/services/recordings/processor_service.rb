# frozen_string_literal: true

module Recordings
  # ProcessorService orchestrates the entire processing pipeline for a recording
  class ProcessorService
    def initialize(recording)
      @recording = recording
    end

    def process
      # Wrap the entire process in a transaction to ensure data consistency
      ApplicationRecord.transaction do
        # Step 1: Apply Kalman filter to smooth the GPS data
        # This step reduces noise and improves accuracy of the recorded locations
        KalmanFilterService.new(@recording).process

        # Step 2: Simplify the path using Visvalingam-Whyatt algorithm
        # This step reduces the number of points while preserving the overall shape
        SimplificationService.new(@recording).process

        # Step 3: Calculate velocity and heading for each point
        # This step computes speed and direction information for each location
        VelocityHeadingService.new(@recording).process

        # Step 4: Calculate overall statistics for the recording
        # This step computes aggregate data like total distance, average speed, etc.
        StatisticsService.new(@recording).process

        # Step 5: Associate with a race if applicable
        # This step links the recording to a race if it's part of one
        Races::AssociationService.new(@recording).associate if @recording.is_race?
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      # Log any database-related errors that occur during processing
      ErrorNotifierService.notify(e, context: { recording_id: @recording.id, error_type: :database_error })
      raise # Re-raise the error to be handled by the caller
    rescue StandardError => e
      # Log any unexpected errors that occur during processing
      ErrorNotifierService.notify(e, context: { recording_id: @recording.id, error_type: :unexpected_error })
      raise # Re-raise the error to be handled by the caller
    end
  end
end
