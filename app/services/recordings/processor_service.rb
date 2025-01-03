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
        instrumentation("kalman_filter") do
          KalmanFilterService.new(@recording).process
        end

        # Step 2: Simplify the path using Visvalingam-Whyatt algorithm
        # This step reduces the number of points while preserving the overall shape
        instrumentation("simplification") do
          SimplificationService.new(@recording).process
        end

        # Step 3: Calculate velocity and heading for each point
        # This step computes speed and direction information for each location
        instrumentation("velocity_heading") do
          VelocityHeadingService.new(@recording).process
        end

        # Step 4: Calculate overall statistics for the recording
        # This step computes aggregate data like total distance, average speed, etc.
        instrumentation("statistics") do
          StatisticsService.new(@recording).process
        end

        # Step 5: Associate with a race if applicable
        # This step links the recording to a race if it's part of one
        if @recording.is_race?
          instrumentation("race_association") do
            Races::AssociationService.new(@recording).associate
          end
        end
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

    private

    private

    # A helper to wrap each pipeline step in a memory profile block
    def instrumentation(step_name, &block)
      return block.call unless instrumentation_enabled?

      # 1) Log GC stats before the step
      log_gc_stats("BEFORE-#{step_name}")

      # 2) Start a memory profile for this step
      step_report = MemoryProfiler.report do
        yield
      end

      # 3) Force GC, log GC stats after
      GC.start
      log_gc_stats("AFTER-#{step_name}")

      # 4) Output the step report to logs instead of files
      step_report.pretty_print do |line|
        Rails.logger.info("MemoryProfiler [#{step_name}]: #{line}")
      end
      Rails.logger.info("MemoryProfiler step results for '#{step_name}' logged.")
    end

    def instrumentation_enabled?
      true
    end

    def log_gc_stats(label)
      stats = GC.stat
      Rails.logger.info("[ProcessorService:MemoryStats] #{@recording.id} - #{label} " \
        "Total Allocated Objects: #{stats[:total_allocated_objects]}, " \
        "Total Freed Objects: #{stats[:total_freed_objects]}, " \
        "Live Slots: #{stats[:heap_live_slots]}, " \
        "Free Slots: #{stats[:heap_free_slots]}, " \
        "Marked Slots: #{stats[:heap_marked_slots]}, " \
        "Malloc Increase Bytes: #{stats[:malloc_increase_bytes]}, " \
        "Minor GC Count: #{stats[:minor_gc_count]}, " \
        "Major GC Count: #{stats[:major_gc_count]}, " \
        "Old Objects: #{stats[:old_objects]}, " \
        "Total Allocated Pages: #{stats[:total_allocated_pages]}, " \
        "Total Freed Pages: #{stats[:total_freed_pages]}")
    end
  end
end
