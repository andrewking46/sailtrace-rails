class RecordingsController < ApplicationController
  before_action :set_recording, only: %i[show track edit update status end destroy]

  def index
    @recordings = Current.user.recordings.order(created_at: :desc)
  end

  def show
    @processing = RecordingProcessorJob.processing?(@recording.id)
  end

  def track
    redirect_to @recording, alert: "Recording has ended" if @recording.ended?
  end

  def new
    @recording = Recording.new
  end

  def create
    @recording = Current.user.recordings.new(recording_params)

    if @recording.save
      redirect_to track_recording_url(@recording), notice: "Recording created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @recording.update(recording_params)
      redirect_to @recording, notice: "Recording updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def end
    if @recording.ended?
      render json: { error: 'Recording already ended' }, status: :unprocessable_entity
    else
      @recording.end!
      render json: { message: 'Recording ended', redirect_url: processing_recording_path(@recording) }, status: :ok
    end
  end

  def destroy
    @recording.destroy!
    redirect_to recordings_url, notice: "Recording destroyed"
  end

  def processing
    @recording = Recording.find(params[:id])
  end

  def status
    render json: {
      status: @recording.status,
      message: status_message(@recording.status)
    }
  end

  private

  def set_recording
    @recording = Current.user.recordings.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to recordings_url, alert: "Recording not found"
  end

  def recording_params
    params.require(:recording).compact_blank.permit(:name, :started_at, :ended_at, :time_zone, :is_race, :boat_id)
  end

  def status_message(status)
    case status
    when 'not_started'
      "Recording not started..."
    when 'in_progress'
      "Recording in progress..."
    when 'processing'
      "Processing your recording..."
    when 'processed'
      "Processing completed"
    else
      "Unknown status"
    end
  end
end
