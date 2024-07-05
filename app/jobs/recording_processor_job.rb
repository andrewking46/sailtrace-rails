class RecordingProcessorJob < ApplicationJob
  queue_as :default

  def perform(recording_id)
    recording = Recording.find(recording_id)
    Recordings::ProcessorService.new(recording).process_locations
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "RecordingProcessorJob: Recording not found - #{e.message}"
    ErrorNotifierService.notify(e, context: { recording_id: recording_id })
  rescue StandardError => e
    Rails.logger.error "RecordingProcessorJob: Error processing recording - #{e.message}"
    ErrorNotifierService.notify(e, context: { recording_id: recording_id })
  end

  def self.processing?(recording_id)
    SolidQueue::Job.where(class_name: name, arguments: [recording_id].to_json)
                   .where.not(finished_at: nil)
                   .exists?
  end

  def self.status(recording_id)
    if processing?(recording_id)
      {
        status: 'processing',
        progress: calculate_progress(recording_id),
        message: 'Processing your recording...'
      }
    else
      { status: 'completed', progress: 100, message: 'Processing completed' }
    end
  end

  private

  def self.calculate_progress(recording_id)
    # This is a placeholder implementation. In a real-world scenario,
    # you'd want to store the progress in a database or cache.
    rand(100)
  end
end
