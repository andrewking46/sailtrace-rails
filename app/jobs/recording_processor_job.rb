# frozen_string_literal: true

class RecordingProcessorJob < ApplicationJob
  queue_as :default
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on Net::OpenTimeout, Timeout::Error, wait: 10.seconds, attempts: 3

  def perform(recording_id)
    return unless instrumentation_enabled?

    recording = Recording.find(recording_id)

    # 1) Log baseline GC stats:
    log_memory_stats(label: "Job Start", recording_id:)

    # 2) Start a high-level memory profiler for the entire job
    #    (Optional if you also do step-by-step. Let's do both for demonstration.)
    @overall_report = MemoryProfiler.report do
      ActiveRecord::Base.transaction do
        Recordings::ProcessorService.new(recording).process
        recording.update!(last_processed_at: Time.current)
      end
    end

    # 3) Force GC, log final memory stats
    GC.start
    log_memory_stats(label: "Job End", recording_id:)

    # 4) Print out the overall report
    @overall_report.pretty_print(to_file: memory_report_file_path("overall", recording_id))
    Rails.logger.info("MemoryProfiler overall job results saved to #{memory_report_file_path('overall', recording_id)}")
  rescue ActiveRecord::RecordNotFound => e
    handle_error(e, recording_id, "Recording not found")
  rescue ActiveRecord::RecordInvalid => e
    handle_error(e, recording_id, "Invalid record")
  rescue StandardError => e
    handle_error(e, recording_id, "Unexpected error")
  end

  def self.processing?(recording_id)
    job = SolidQueue::Job.where(class_name: name, arguments: [ recording_id ].to_json)
                         .where.not(finished_at: nil)
                         .order(created_at: :desc)
                         .first
    job.present? && job.finished_at.nil?
  end

  private

  def handle_error(error, recording_id, _message)
    ErrorNotifierService.notify(error, context: { recording_id: })
  end

  # Utility method to check if instrumentation is turned on.
  def instrumentation_enabled?
    # e.g. we only run instrumentation in dev/staging
    Rails.env.development? || Rails.env.staging?
  end

  def log_memory_stats(label:, recording_id:)
    stats = GC.stat
    mem = memory_for_process
    Rails.logger.info("[MemoryStats] [Recording=#{recording_id}] [#{label}] " \
      "Heap Used: #{stats[:heap_used]}, " \
      "Heap Length: #{stats[:heap_length]}, " \
      "Total Allocated: #{stats[:total_allocated_objects]}, " \
      "Live Objects: #{stats[:heap_live_slots]}, " \
      "Process Memory MB: #{(mem / 1024.0 / 1024.0).round(2)}")
  end

  # Helper to get overall memory usage of the Ruby process
  def memory_for_process
    # If we have the gem 'get_process_mem'
    if defined?(GetProcessMem)
      GetProcessMem.new.mb * 1024 * 1024
    else
      # fallback: can do `ps` or simply 0
      0
    end
  end

  def memory_report_file_path(step, recording_id)
    FileUtils.mkdir_p("/tmp/memory_profiles")
    "/tmp/memory_profiles/recording_#{recording_id}_#{step}.txt"
  end
end
