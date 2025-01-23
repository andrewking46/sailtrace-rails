module My
  class BoatsController < BaseController
    before_action :set_boat, only: %i[show edit update destroy]

    def index
      add_breadcrumb("Boats")
      @boats = Current.user.boats.includes(:boat_class).order(:name)
    end

    def show
      add_breadcrumb("Boats", my_boats_path)
      add_breadcrumb(@boat.name)
    end

    def new
      @boat = Boat.new
      @available_orgs = (YachtClub.order(:name) + SailingTeam.order(:name))
    end

    def edit
      add_breadcrumb("Boats", my_boats_path)
      add_breadcrumb(@boat.name, my_boat_path(@boat))
      add_breadcrumb("Edit")
      @available_orgs = (YachtClub.order(:name) + SailingTeam.order(:name))
    end

    def create
      @boat = Boat.new(boat_params)

      respond_to do |format|
        if @boat.save
          format.html { redirect_to my_boat_url(@boat), notice: "Boat saved" }
          format.json { render :show, status: :created, location: @boat }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @boat.errors, status: :unprocessable_entity }
        end
      end
    end

    def update
      respond_to do |format|
        if @boat.update(boat_params)
          format.html { redirect_to my_boat_url(@boat), notice: "Boat saved" }
          format.json { render :show, status: :ok, location: @boat }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @boat.errors, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      @boat.destroy!

      respond_to do |format|
        format.html { redirect_to my_boats_url, notice: "Boat destroyed" }
        format.json { head :no_content }
      end
    end

    private

    def set_boat
      @boat = Current.user.boats.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to my_boats_url, alert: "Boat not found"
    end

    def boat_params
      params.require(:boat).compact_blank.permit(:name, :registration_country, :sail_number, :hull_color, :boat_class_id, :organization_type, :organization_id)
    end
  end
end
