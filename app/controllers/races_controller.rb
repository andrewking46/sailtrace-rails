class RacesController < ApplicationController
  allow_unauthenticated_access
  before_action :set_race

  # GET /races/:id
  # By default, this renders show.html.erb or show.json.jbuilder
  #
  def show
    respond_to do |format|
      format.html
      format.json do
        if signed_in?
          # Return the real race data
        else
          render json: { error: "Please log in to view race details" }, status: :unauthorized
        end
      end
    end
  end

  private

  def set_race
    @race = Race.find(params[:id])
  end
end
