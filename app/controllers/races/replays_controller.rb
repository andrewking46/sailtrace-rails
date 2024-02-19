class Races::ReplaysController < ApplicationController
  before_action :set_race

  def show
    @user_recording = @race.recordings.find_by(user_id: Current.user.id)
  end

  private
    def set_race
      @race = Race.find(params[:race_id])
    end
end
