module Admin
  class BoatClassesController < BaseController
    before_action :set_boat_class, only: %i[show edit update destroy]

    # GET /boat_classes or /boat_classes.json
    def index
      add_breadcrumb("Boat classes")
      @boat_classes = BoatClass.all.order(:name)
    end

    # GET /boat_classes/1 or /boat_classes/1.json
    def show
      add_breadcrumb("Boat classes", admin_boat_classes_path)
      add_breadcrumb(@boat_class.name)
    end

    # GET /boat_classes/new
    def new
      add_breadcrumb("Boat classes", admin_boat_classes_path)
      add_breadcrumb("New")
      @boat_class = BoatClass.new
    end

    # GET /boat_classes/1/edit
    def edit
      add_breadcrumb("Boat classes", admin_boat_classes_path)
      add_breadcrumb(@boat_class.name, admin_boat_class_path(@boat_class))
      add_breadcrumb("Edit")
    end

    # POST /boat_classes or /boat_classes.json
    def create
      @boat_class = BoatClass.new(boat_class_params)

      respond_to do |format|
        if @boat_class.save
          format.html { redirect_to admin_boat_class_url(@boat_class), notice: "Boat class created" }
          format.json { render :show, status: :created, location: @boat_class }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @boat_class.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /boat_classes/1 or /boat_classes/1.json
    def update
      respond_to do |format|
        if @boat_class.update(boat_class_params)
          format.html { redirect_to admin_boat_class_url(@boat_class), notice: "Boat class updated" }
          format.json { render :show, status: :ok, location: @boat_class }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @boat_class.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /boat_classes/1 or /boat_classes/1.json
    def destroy
      @boat_class.destroy!

      respond_to do |format|
        format.html { redirect_to admin_boat_classes_url, notice: "Boat class deleted" }
        format.json { head :no_content }
      end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_boat_class
      @boat_class = BoatClass.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def boat_class_params
      params.require(:boat_class).compact_blank.permit(:name, :is_one_design)
    end
  end
end
