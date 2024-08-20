# test/models/recorded_location_test.rb

require "test_helper"

class RecordedLocationTest < ActiveSupport::TestCase
  def setup
    @recording = recordings(:in_progress)
    @recorded_location = RecordedLocation.new(
      latitude: 40.7128,
      longitude: -74.0060,
      velocity: 5.5,
      heading: 180,
      accuracy: 10.0,
      recorded_at: Time.current,
      recording: @recording
    )
  end

  test "valid recorded location" do
    assert @recorded_location.valid?
  end

  test "invalid without latitude" do
    @recorded_location.latitude = nil
    assert_not @recorded_location.valid?
    assert_includes @recorded_location.errors[:latitude], "can't be blank"
  end

  test "invalid without longitude" do
    @recorded_location.longitude = nil
    assert_not @recorded_location.valid?
    assert_includes @recorded_location.errors[:longitude], "can't be blank"
  end

  test "invalid without recording" do
    @recorded_location.recording = nil
    assert_not @recorded_location.valid?
    assert_includes @recorded_location.errors[:recording], "must exist"
  end

  test "invalid without recorded_at" do
    @recorded_location.recorded_at = nil
    assert_not @recorded_location.valid?
    assert_includes @recorded_location.errors[:recorded_at], "can't be blank"
  end

  test "belongs to recording" do
    assert_respond_to @recorded_location, :recording
    assert_instance_of Recording, @recorded_location.recording
  end

  test "latitude must be between -90 and 90" do
    @recorded_location.latitude = 91
    assert_not @recorded_location.valid?
    assert_includes @recorded_location.errors[:latitude], "must be less than or equal to 90"

    @recorded_location.latitude = -91
    assert_not @recorded_location.valid?
    assert_includes @recorded_location.errors[:latitude], "must be greater than or equal to -90"
  end

  test "longitude must be between -180 and 180" do
    @recorded_location.longitude = 181
    assert_not @recorded_location.valid?
    assert_includes @recorded_location.errors[:longitude], "must be less than or equal to 180"

    @recorded_location.longitude = -181
    assert_not @recorded_location.valid?
    assert_includes @recorded_location.errors[:longitude], "must be greater than or equal to -180"
  end

  test "heading must be between 0 and 360" do
    @recorded_location.heading = 361
    assert_not @recorded_location.valid?
    assert_includes @recorded_location.errors[:heading], "must be less than or equal to 360"

    @recorded_location.heading = -1
    assert_not @recorded_location.valid?
    assert_includes @recorded_location.errors[:heading], "must be greater than or equal to 0"
  end

  test "recorded_at cannot be in the future" do
    @recorded_location.recorded_at = 1.day.from_now
    assert_not @recorded_location.valid?
    assert_includes @recorded_location.errors[:recorded_at], "can't be in the future"
  end

  test "recorded_at can be in the past" do
    @recorded_location.recorded_at = 1.day.ago
    assert @recorded_location.valid?
  end

  test "recorded_at can be the current time" do
    @recorded_location.recorded_at = Time.current
    assert @recorded_location.valid?
  end
end
