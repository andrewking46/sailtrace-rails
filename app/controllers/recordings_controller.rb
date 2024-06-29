class RecordingsController < ApplicationController
  before_action :set_recording, only: %i[ show track edit update end destroy ]

  # GET /recordings or /recordings.json
  def index
    @recordings = Current.user.recordings.order(created_at: :desc)
  end

  # GET /recordings/1 or /recordings/1.json
  def show
  end

  # GET /recordings/1/track
  def track
    redirect_to recordings_url if @recording.ended?
  end

  # GET /recordings/new
  def new
    @recording = Recording.new
  end

  # GET /recordings/1/edit
  def edit
  end

  # POST /recordings or /recordings.json
  def create
    @recording = Recording.new(recording_params)

    respond_to do |format|
      if @recording.save
        format.html { redirect_to track_recording_url(@recording), notice: "Recording created" }
        format.json { render :show, status: :created, location: @recording }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @recording.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /recordings/1 or /recordings/1.json
  def update
    respond_to do |format|
      if @recording.update(recording_params)
        format.html { redirect_to recording_url(@recording), notice: "Recording updated" }
        format.json { render :show, status: :ok, location: @recording }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @recording.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /recordings/1/end
  def end
    if @recording.ended?
      render json: { error: 'Recording already ended' }, status: :unprocessable_entity
      return
    end

    @recording.end!
    render json: { message: 'Recording ended' }, status: :ok
  end

  # DELETE /recordings/1 or /recordings/1.json
  def destroy
    @recording.destroy!

    respond_to do |format|
      format.html { redirect_to recordings_url, notice: "Recording destroyed" }
      format.json { head :no_content }
    end
  end

  private
    def set_recording
      if recording = Current.user.recordings.find(params[:id])
        @recording = recording
      else
        redirect_to recordings_url, alert: "Recording not found"
      end
    end

    # Only allow a list of trusted parameters through.
    def recording_params
      params.require(:recording).compact_blank.permit(:name, :started_at, :ended_at, :time_zone, :is_race, :boat_id)
    end
end
