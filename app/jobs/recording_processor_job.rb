class RecordingProcessorJob < ApplicationJob
  queue_as :default
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on Net::OpenTimeout, Timeout::Error, wait: 10.seconds, attempts: 3

  def perform(recording_id)
    recording = Recording.find(recording_id)

    ActiveRecord::Base.transaction do
      Recordings::ProcessorService.new(recording).process
      recording.update!(last_processed_at: Time.current)
    end

    GC.start
  rescue ActiveRecord::RecordNotFound => e
    handle_error(e, recording_id, "Recording not found")
  rescue ActiveRecord::RecordInvalid => e
    handle_error(e, recording_id, "Invalid record")
  rescue StandardError => e
    handle_error(e, recording_id, "Unexpected error")
  end

  def self.processing?(recording_id)
    job = SolidQueue::Job.where(class_name: name, arguments: [recording_id].to_json)
                         .where.not(finished_at: nil)
                         .order(created_at: :desc)
                         .first
    job.present? && job.finished_at.nil?
  end

  private

  def handle_error(error, recording_id, message)
    ErrorNotifierService.notify(error, context: { recording_id: recording_id })
  end
end
