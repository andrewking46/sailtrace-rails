module MetaTags
  module UserHelper
    include BaseHelper

    # Generate meta tags for a user profile page
    # @param user [User] The user object
    # @return [ActiveSupport::SafeBuffer] HTML meta tags for the user profile
    def user_meta_tags(user)
      meta_tags(
        title: "#{user.full_name} - SailTrace Sailor Profile",
        description: user_description(user),
        image: user_image(user),
        type: "profile",
        schema_type: :user,
        entity: user,
        url: user_url(user)
      )
    end

    private

    def user_description(user)
      "#{user.full_name}'s SailTrace profile. " \
      "#{user.boats.count} registered boats. " \
      "#{user.recordings.count} recorded sails. " \
      "Total sailing distance: #{total_sailing_distance(user)}km. " \
      "Follow #{user.first_name}'s sailing adventures on SailTrace!"
    end

    def user_image(user)
      # Assuming you have ActiveStorage set up for user avatars
      user.avatar.attached? ? user.avatar : "default_user_image.jpg"
    end

    def total_sailing_distance(user)
      user.recordings.sum(&:calculate_distance).round(2)
    end
  end
end
