module MetaTags
  module RaceHelper
    include BaseHelper

    # Generate meta tags for a race page
    # @param race [Race] The race object
    # @return [ActiveSupport::SafeBuffer] HTML meta tags for the race
    def race_meta_tags(race)
      meta_tags(
        title: "#{race.name} - SailTrace Race",
        # description: race_description(race),
        # image: race_image(race),
        type: 'article',
        schema_type: :race,
        entity: race,
        url: race_url(race)
      )
    end

    private

    def race_description(race)
      "#{race.name} on #{I18n.l(race.started_at, format: :long)}. " \
      "#{race.recordings.count} participants. " \
      "#{race.boat_class ? "Boat class: #{race.boat_class.name}." : ''} "
    end

    def race_image(race)
      # Placeholder for race image. In the future, you might want to generate
      # a map image of the race course or use a photo from the event.
      '/logos/sailtrace-logo.png'
    end
  end
end
