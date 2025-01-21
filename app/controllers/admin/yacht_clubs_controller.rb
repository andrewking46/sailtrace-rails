module Admin
  class YachtClubsController < BaseController
    before_action :set_yacht_club, only: %i[show edit update destroy]

    def index
      @yacht_clubs = YachtClub.order(:name)
    end

    def show
    end

    def new
      @yacht_club = YachtClub.new
    end

    def create
      @yacht_club = YachtClub.new(yacht_club_params)
      if @yacht_club.save
        redirect_to admin_yacht_club_path(@yacht_club), notice: "Yacht Club created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @yacht_club.update(yacht_club_params)
        redirect_to admin_yacht_club_path(@yacht_club), notice: "Yacht Club updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @yacht_club.destroy
      redirect_to admin_yacht_clubs_path, notice: "Yacht Club deleted."
    end

    private

    def set_yacht_club
      @yacht_club = YachtClub.find(params[:id])
    end

    def yacht_club_params
      params.require(:yacht_club).permit(
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
