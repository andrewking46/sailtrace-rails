class RacesController < ApplicationController
  allow_unauthenticated_access
  before_action :set_race

  def show; end

  private

  def set_race
    @race = Race.find(params[:id])
  end
end
