module Admin
  class SailingTeamsController < BaseController
    before_action :set_sailing_team, only: %i[show edit update destroy]

    def index
      add_breadcrumb("Sailing teams")
      @sailing_teams = SailingTeam.order(:name)
    end

    def show
    end

    def new
      @sailing_team = SailingTeam.new
    end

    def create
      @sailing_team = SailingTeam.new(sailing_team_params)
      if @sailing_team.save
        redirect_to admin_sailing_team_path(@sailing_team), notice: "Sailing Team created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @sailing_team.update(sailing_team_params)
        redirect_to admin_sailing_team_path(@sailing_team), notice: "Sailing Team updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @sailing_team.destroy
      redirect_to admin_sailing_teams_path, notice: "Sailing Team deleted."
    end

    private

    def set_sailing_team
      @sailing_team = SailingTeam.find(params[:id])
    end

    def sailing_team_params
      params.require(:sailing_team).permit(
        :name,
        :abbreviation,
        :street_address,
        :city,
        :subdivision_code,
        :subdivision,
        :postal_code,
        :country_code,
        :country,
        :time_zone,
        :latitude,
        :longitude,
        :phone,
        :email,
        :is_active,
        :burgee
      )
    end
  end
end
