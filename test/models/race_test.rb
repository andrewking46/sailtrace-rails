# test/models/race_test.rb

require 'test_helper'

class RaceTest < ActiveSupport::TestCase
  def setup
    @boat_class = boat_classes(:laser)
    @race = Race.new(
      name: "Weekend Regatta",
      started_at: Time.current,
      start_latitude: 40.7128,
      start_longitude: -74.0060,
      boat_class: @boat_class
    )
  end

  test "valid race" do
    assert @race.valid?
  end

  test "invalid without started_at" do
    @race.started_at = nil
    assert_not @race.valid?
    assert_includes @race.errors[:started_at], "can't be blank"
  end

  test "invalid without start_latitude" do
    @race.start_latitude = nil
    assert_not @race.valid?
    assert_includes @race.errors[:start_latitude], "can't be blank"
  end

  test "invalid without start_longitude" do
    @race.start_longitude = nil
    assert_not @race.valid?
    assert_includes @race.errors[:start_longitude], "can't be blank"
  end

  test "belongs to boat_class (optional)" do
    assert_respond_to @race, :boat_class
    @race.boat_class = nil
    assert @race.valid?
  end

  test "has many recordings" do
    assert_respond_to @race, :recordings
    assert_empty @race.recordings
  end

  test "ended_at returns latest recording end time" do
    @race.save
    recording1 = @race.recordings.create(ended_at: 1.hour.ago)
    recording2 = @race.recordings.create(ended_at: 30.minutes.ago)
    assert_equal recording2.ended_at, @race.ended_at
  end

  test "empty scope returns races with no recordings" do
    empty_race = @race.dup
    empty_race.save
    @race.save
    @race.recordings.create
    assert_includes Race.empty, empty_race
    assert_not_includes Race.empty, @race
  end

  test "finalize updates race attributes" do
    @race.save
    boat1 = boats(:sailboat)
    boat2 = boats(:racing_yacht)
    @race.recordings.create(started_at: 10.minutes.ago, boat: boat1)
    @race.recordings.create(started_at: 5.minutes.ago, boat: boat2)

    @race.finalize

    assert_equal @race.recordings.minimum(:started_at), @race.started_at
    assert_in_delta @race.recordings.average(:start_latitude), @race.start_latitude, 0.0001
    assert_in_delta @race.recordings.average(:start_longitude), @race.start_longitude, 0.0001
  end

  test "destroy_if_empty destroys race if it has no recordings" do
    @race.save
    assert_difference 'Race.count', -1 do
      @race.destroy_if_empty
    end
  end

  test "destroy_if_empty does not destroy race if it has recordings" do
    @race.save
    @race.recordings.create
    assert_no_difference 'Race.count' do
      @race.destroy_if_empty
    end
  end
end
