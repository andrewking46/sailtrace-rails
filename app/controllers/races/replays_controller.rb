class Races::ReplaysController < ApplicationController
  before_action :set_race

  def show; end

  private
    def set_race
      @race = Race.find(params[:race_id])
    end
end
