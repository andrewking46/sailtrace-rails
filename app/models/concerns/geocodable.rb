module Geocodable
  extend ActiveSupport::Concern

  included do
    reverse_geocoded_by :start_latitude, :start_longitude
  end

  def set_start_location
    return if start_latitude.present? && start_longitude.present?
    if (first_location = recorded_locations.order(created_at: :asc).first)
      update(start_latitude: first_location.latitude, start_longitude: first_location.longitude)
    end
  end
end
