require 'test_helper'
require 'active_job/test_helper'
require 'minitest/mock'

class RecordingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @in_progress = recordings(:in_progress)
    @completed = recordings(:completed)
    @processed = recordings(:processed)
  end

  test "valid recordings" do
    assert @in_progress.valid?, "in_progress recording should be valid"
    assert @completed.valid?, "completed recording should be valid"
    assert @processed.valid?, "processed recording should be valid"
  end

  test "invalid without required attributes" do
    recording = Recording.new
    assert_not recording.valid?
    assert_includes recording.errors[:time_zone], "can't be blank"
    assert_includes recording.errors[:boat], "must exist"
    assert_includes recording.errors[:user], "must exist"
  end

  test "associations" do
    assert_respond_to @in_progress, :boat
    assert_respond_to @in_progress, :user
    assert_respond_to @in_progress, :race
    assert_respond_to @in_progress, :recorded_locations
  end

  test "in_progress scope" do
    assert_includes Recording.in_progress, @in_progress
    assert_not_includes Recording.in_progress, @completed
    assert_not_includes Recording.in_progress, @processed
  end

  test "end!" do
    assert_nil @in_progress.ended_at
    @in_progress.end!
    assert_not_nil @in_progress.ended_at
    assert_in_delta Time.current, @in_progress.ended_at, 1.second
  end

  test "ended?" do
    assert_not @in_progress.ended?
    assert @completed.ended?
    assert @processed.ended?
  end

  test "calculate_distance" do
    assert_equal 15.5, @completed.calculate_distance
    assert_equal 8.2, @processed.calculate_distance

    # Mock the DistanceCalculationService for the in_progress recording
    service = Minitest::Mock.new
    service.expect :calculate, 10.5
    Recordings::DistanceCalculationService.stub :new, service do
      assert_equal 10.5, @in_progress.calculate_distance
    end
  end

  test "average_speed" do
    assert_equal 0, @in_progress.average_speed
    assert_in_delta 15.5, @completed.average_speed, 0.1
    assert_in_delta 4.1, @processed.average_speed, 0.01
  end

  test "status" do
    assert_equal :in_progress, @in_progress.status
    assert_equal :processing, @completed.status
    assert_equal :processed, @processed.status

    new_recording = Recording.new
    assert_equal :not_started, new_recording.status
  end

  test "set_started_at callback" do
    recording = Recording.new(time_zone: "UTC", boat: @in_progress.boat, user: @in_progress.user)
    assert_nil recording.started_at
    recording.save!
    assert_not_nil recording.started_at
    assert_in_delta Time.current, recording.started_at, 1.second
  end

  test "process_ending callback" do
    assert_enqueued_with(job: RecordingProcessorJob) do
      @in_progress.update!(ended_at: Time.current)
    end
  end

  test "cleanup_race callback" do
    assert_difference 'Race.count', -1 do
      @completed.destroy
    end
    assert_no_difference 'Race.count' do
      @in_progress.destroy
    end
  end

  test "end_after_start validation" do
    @in_progress.ended_at = @in_progress.started_at - 1.hour
    assert_not @in_progress.valid?
    assert_includes @in_progress.errors[:ended_at], "must be after the start time"
  end

  test "set_start_location" do
    new_recording = Recording.create!(
      name: "New Test",
      time_zone: "UTC",
      boat: @in_progress.boat,
      user: @in_progress.user
    )
    assert_nil new_recording.start_latitude
    assert_nil new_recording.start_longitude

    location = new_recording.recorded_locations.create!(latitude: 40.7128, longitude: -74.0060)
    new_recording.send(:set_start_location)
    new_recording.reload

    assert_equal location.latitude, new_recording.start_latitude
    assert_equal location.longitude, new_recording.start_longitude
  end

  test "duration" do
    assert_equal "00:00:00", @in_progress.duration
    assert_equal "01:00:00", @completed.duration
    assert_equal "02:00:00", @processed.duration
  end

  test "duration_seconds" do
    assert_equal 0, @in_progress.duration_seconds
    assert_equal 3600, @completed.duration_seconds
    assert_equal 7200, @processed.duration_seconds
  end

  test "recorded_locations association" do
    assert_equal 2, @in_progress.recorded_locations.count
    assert_equal 1, @completed.recorded_locations.count
    assert_equal 1, @processed.recorded_locations.count
  end

  test "race association" do
    assert_nil @in_progress.race
    assert_not_nil @completed.race
    assert_equal races(:saturday_regatta).name, @completed.race.name
  end
end
