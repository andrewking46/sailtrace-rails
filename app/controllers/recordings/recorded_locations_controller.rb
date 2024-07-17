module Recordings
  class RecordedLocationsController < BaseController
    def index
      @recorded_locations = @recording.recorded_locations.order(created_at: :asc)
      render json: @recorded_locations
    end
  end
end
