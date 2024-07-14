class RecordingProcessorJob < ApplicationJob
  queue_as :default
  retry_on ActiveRecord::Deadlock, wait: 5.seconds, attempts: 3
  retry_on Net::OpenTimeout, Timeout::Error, wait: 10.seconds, attempts: 3

  def perform(recording_id)
    Rails.logger.info "RecordingProcessorJob started for recording_id: #{recording_id}"
    recording = Recording.find(recording_id)

    ActiveRecord::Base.transaction do
      Recordings::ProcessorService.new(recording).process
      recording.update!(last_processed_at: Time.current)
    end

    Rails.logger.info "RecordingProcessorJob finished for recording_id: #{recording_id}"
  rescue ActiveRecord::RecordNotFound => e
    handle_error(e, recording_id, "Recording not found")
  rescue ActiveRecord::RecordInvalid => e
    handle_error(e, recording_id, "Invalid record")
  rescue Recordings::ProcessorError => e
    handle_error(e, recording_id, "Processing error")
  end

  def self.processing?(recording_id)
    SolidQueue::Job.where(class_name: name, arguments: [recording_id].to_json)
                   .where.not(finished_at: nil)
                   .exists?
  end

  private

  def handle_error(error, recording_id, message)
    Rails.logger.error "RecordingProcessorJob: #{message} - #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    ErrorNotifierService.notify(error, context: { recording_id: recording_id })
  end
end
