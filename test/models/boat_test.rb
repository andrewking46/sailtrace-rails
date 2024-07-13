# test/models/boat_test.rb

require 'test_helper'

class BoatTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @boat_class = boat_classes(:laser)
    @boat = Boat.new(
      name: "Sea Breeze",
      registration_country: "US",
      sail_number: "USA1234",
      hull_color: "White",
      boat_class: @boat_class,
      user: @user
    )
  end

  test "valid boat" do
    assert @boat.valid?
  end

  test "invalid without name" do
    @boat.name = nil
    assert_not @boat.valid?
    assert_includes @boat.errors[:name], "can't be blank"
  end

  test "invalid without registration_country" do
    @boat.registration_country = nil
    assert_not @boat.valid?
    assert_includes @boat.errors[:registration_country], "can't be blank"
  end

  test "invalid without sail_number" do
    @boat.sail_number = nil
    assert_not @boat.valid?
    assert_includes @boat.errors[:sail_number], "can't be blank"
  end

  test "invalid without hull_color" do
    @boat.hull_color = nil
    assert_not @boat.valid?
    assert_includes @boat.errors[:hull_color], "can't be blank"
  end

  test "invalid without boat_class" do
    @boat.boat_class = nil
    assert_not @boat.valid?
    assert_includes @boat.errors[:boat_class], "must exist"
  end

  test "invalid without user" do
    @boat.user = nil
    assert_not @boat.valid?
    assert_includes @boat.errors[:user], "must exist"
  end

  test "belongs to boat_class" do
    assert_respond_to @boat, :boat_class
    assert_instance_of BoatClass, @boat.boat_class
  end

  test "belongs to user" do
    assert_respond_to @boat, :user
    assert_instance_of User, @boat.user
  end

  test "has many recordings" do
    assert_respond_to @boat, :recordings
    assert_empty @boat.recordings
  end

  test "sail_number must be unique within registration_country" do
    duplicate_boat = @boat.dup
    @boat.save
    assert_not duplicate_boat.valid?
    assert_includes duplicate_boat.errors[:sail_number], "has already been taken"
  end

  test "sail_number can be duplicated across different countries" do
    @boat.save
    different_country_boat = @boat.dup
    different_country_boat.registration_country = "UK"
    assert different_country_boat.valid?
  end
end
