module MetaTags
  module SchemaOrgHelper
    def generate_schema_org(entity, type)
      case type
      when :race
        race_schema(entity)
      when :recording
        recording_schema(entity)
      when :boat
        boat_schema(entity)
      when :user
        user_schema(entity)
      else
        default_schema(entity)
      end
    end

    private

    def race_schema(race)
      {
        "@context" => "https://schema.org",
        "@type" => "SportsEvent",
        "name" => race.name,
        "startDate" => race.started_at.iso8601,
        "endDate" => (race.ended_at || race.started_at + 2.hours).iso8601,
        "location" => {
          "@type" => "Place",
          "name" => "Start",
          "geo" => {
            "@type" => "GeoCoordinates",
            "latitude" => race.start_latitude,
            "longitude" => race.start_longitude
          }
        },
        "sport" => "Sailing"
      }
    end

    def recording_schema(recording)
      {
        "@context" => "https://schema.org",
        "@type" => "SportsEvent",
        "name" => recording.name,
        "startDate" => recording.started_at.iso8601,
        "endDate" => (recording.ended_at || recording.started_at + 1.hour).iso8601,
        "location" => {
          "@type" => "Place",
          "name" => "Recording Start Point",
          "geo" => {
            "@type" => "GeoCoordinates",
            "latitude" => recording.start_latitude,
            "longitude" => recording.start_longitude
          }
        },
        "sport" => "Sailing",
        "athlete" => {
          "@type" => "Person",
          "name" => recording.user.full_name
        },
        "vehicle" => {
          "@type" => "Vehicle",
          "name" => recording.boat.name,
          "model" => recording.boat.boat_class.name
        }
      }
    end

    def boat_schema(boat)
      {
        "@context" => "https://schema.org",
        "@type" => "Vehicle",
        "name" => boat.name,
        "model" => boat.boat_class.name,
        "vehicleConfiguration" => "Sail number: #{boat.sail_number}, Hull color: #{boat.hull_color}",
        "owner" => {
          "@type" => "Person",
          "name" => boat.user.full_name
        }
      }
    end

    def user_schema(user)
      {
        "@context" => "https://schema.org",
        "@type" => "Person",
        "name" => user.full_name,
        "nationality" => user.country,
        "knowsAbout" => "Sailing",
        "owns" => user.boats.map do |boat|
          {
            "@type" => "Vehicle",
            "name" => boat.name,
            "model" => boat.boat_class.name
          }
        end
      }
    end

    def default_schema(entity)
      {
        "@context" => "https://schema.org",
        "@type" => "WebPage",
        "name" => entity.try(:name) || "SailTrace Page",
        "description" => "Sailing information on SailTrace"
      }
    end
  end
end
