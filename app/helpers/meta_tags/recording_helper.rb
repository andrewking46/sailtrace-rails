module MetaTags
  module RecordingHelper
    include BaseHelper

    # Generate meta tags for a recording page
    # @param recording [Recording] The recording object
    # @return [ActiveSupport::SafeBuffer] HTML meta tags for the recording
    def recording_meta_tags(recording)
      meta_tags(
        title: "#{recording.name} - SailTrace Recording",
        description: recording_description(recording),
        image: recording_image(recording),
        type: 'article',
        schema_type: :recording,
        entity: recording,
        url: recording_url(recording)
      )
    end

    private

    def recording_description(recording)
      "Sailing recording of #{recording.boat.name} " \
      "#{recording.is_race ? "in #{recording.race.name} " : ''}" \
      "on #{I18n.l(recording.started_at, format: :long)}. " \
      "Duration: #{formatted_duration(recording.duration_seconds)}. " \
      "Distance: #{recording.calculate_distance.round(2)}km. " \
      "Average speed: #{recording.average_speed}km/h. " \
      "Replay and analyze this sail on SailTrace!"
    end

    def recording_image(recording)
      # Placeholder for recording image. In the future, you might want to generate
      # a map image of the recording track or use a photo from the event.
      'default_recording_image.jpg'
    end

    def formatted_duration(seconds)
      Time.at(seconds).utc.strftime("%H:%M:%S")
    end
  end
end
