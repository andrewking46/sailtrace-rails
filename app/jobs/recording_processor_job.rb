# frozen_string_literal: true

class RecordingProcessorJob < ApplicationJob
  queue_as :default
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on Net::OpenTimeout, Timeout::Error, wait: 10.seconds, attempts: 3

  def perform(recording_id)
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
    # @overall_report.pretty_print(to_file: memory_report_file_path("overall", recording_id))
    @overall_report.pretty_print do |line|
      Rails.logger.info(line)
    end
    # Rails.logger.info("MemoryProfiler overall job results saved to #{memory_report_file_path('overall', recording_id)}")
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

  def log_memory_stats(label:, recording_id:)
    stats = GC.stat
    mem = memory_for_process
    Rails.logger.info("[MemoryStats] [Recording=#{recording_id}] [#{label}] " \
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
      "Total Freed Pages: #{stats[:total_freed_pages]}, " \
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
