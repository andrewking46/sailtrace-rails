class RecordingProcessorJob < ApplicationJob
  queue_as :default

  def perform(recording_id)
    Rails.logger.info "RecordingProcessorJob started for recording_id: #{recording_id}"
    recording = Recording.find(recording_id)
    Rails.logger.info "Recording found: #{recording.inspect}"
    result = Recordings::ProcessorService.new(recording).process
    Rails.logger.info "Processing completed with result: #{result.inspect}"
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "RecordingProcessorJob: Recording not found - #{e.message}"
    ErrorNotifierService.notify(e, context: { recording_id: recording_id })
  rescue StandardError => e
    Rails.logger.error "RecordingProcessorJob: Error processing recording - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    ErrorNotifierService.notify(e, context: { recording_id: recording_id })
  ensure
    Rails.logger.info "RecordingProcessorJob finished for recording_id: #{recording_id}"
  end

  def self.processing?(recording_id)
    SolidQueue::Job.where(class_name: name, arguments: [recording_id].to_json)
                   .where.not(finished_at: nil)
                   .exists?
  end
end
