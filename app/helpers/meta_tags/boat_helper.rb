module MetaTags
  module BoatHelper
    include BaseHelper

    # Generate meta tags for a boat page
    # @param boat [Boat] The boat object
    # @return [ActiveSupport::SafeBuffer] HTML meta tags for the boat
    def boat_meta_tags(boat)
      meta_tags(
        title: "#{boat.name} - SailTrace Boat Profile",
        description: boat_description(boat),
        image: boat_image(boat),
        type: "profile",
        schema_type: :boat,
        entity: boat,
        url: boat_url(boat)
      )
    end

    private

    def boat_description(boat)
      "#{boat.name} - a #{boat.boat_class.name} class boat. " \
      "Sail number: #{boat.sail_number}. " \
      "Hull color: #{boat.hull_color}. " \
      "Owned by #{boat.user.full_name}. " \
      "#{boat.recordings.count} recorded sails on SailTrace."
    end

    def boat_image(boat)
      # Assuming you have ActiveStorage set up for boat images
      boat.photo.attached? ? boat.photo : "default_boat_image.jpg"
    end
  end
end
