class CacheRecordingJsonJob < ApplicationJob
  queue_as :low_priority

  def perform(recording_id)
    recording = Recording.find(recording_id)
    CacheManager.fetch("#{recording.cache_key}/json", expires_in: 1.week) do
      RecordingsController.render(formats: :json, locals: { recording: recording })
    end
  end
end
