class RecordedLocationsController < ApplicationController
  before_action :set_recording

  # GET /recorded_locations or /recorded_locations.json
  def index
    recorded_locations = @recording.recorded_locations.order(created_at: :asc)

    render json: recorded_locations
  end

  # POST /recorded_locations or /recorded_locations.json
  def create
    if @recording.ended?
      render json: { error: 'Recording has already ended' }, status: :unprocessable_entity
      return
    end

    @recorded_location = @recording.recorded_locations.new(recorded_location_params)

    if @recorded_location.save
      render json: @recorded_location, status: :created
    else
      render json: @recorded_location.errors, status: :unprocessable_entity
    end
  end

  private
    def set_recording
      @recording = Recording.find(params[:recording_id])
    end

    # Only allow a list of trusted parameters through.
    def recorded_location_params
      params.require(:recorded_location).permit(:latitude, :longitude, :velocity, :heading, :accuracy)
    end
end
