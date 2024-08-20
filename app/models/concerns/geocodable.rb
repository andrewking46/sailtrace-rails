module Geocodable
  extend ActiveSupport::Concern

  included do
    reverse_geocoded_by :start_latitude, :start_longitude
  end
end
