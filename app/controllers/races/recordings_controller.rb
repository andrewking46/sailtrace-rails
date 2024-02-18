class Races::RecordingsController < ApplicationController
  before_action :set_race

  def index
    @recordings = @race.recordings.includes(:boat, :recorded_locations)
  end

  private
    def set_race
      @race = Race.find(params[:race_id])
    end
end
