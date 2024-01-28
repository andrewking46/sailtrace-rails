require "application_system_test_case"

class BoatsTest < ApplicationSystemTestCase
  setup do
    @boat = boats(:one)
  end

  test "visiting the index" do
    visit boats_url
    assert_selector "h1", text: "Boats"
  end

  test "should create boat" do
    visit boats_url
    click_on "New boat"

    fill_in "Boat class", with: @boat.boat_class_id
    fill_in "Hull color", with: @boat.hull_color
    fill_in "Name", with: @boat.name
    fill_in "Registration country", with: @boat.registration_country
    fill_in "Sail number", with: @boat.sail_number
    fill_in "User", with: @boat.user_id
    click_on "Create Boat"

    assert_text "Boat was successfully created"
    click_on "Back"
  end

  test "should update Boat" do
    visit boat_url(@boat)
    click_on "Edit this boat", match: :first

    fill_in "Boat class", with: @boat.boat_class_id
    fill_in "Hull color", with: @boat.hull_color
    fill_in "Name", with: @boat.name
    fill_in "Registration country", with: @boat.registration_country
    fill_in "Sail number", with: @boat.sail_number
    fill_in "User", with: @boat.user_id
    click_on "Update Boat"

    assert_text "Boat was successfully updated"
    click_on "Back"
  end

  test "should destroy Boat" do
    visit boat_url(@boat)
    click_on "Destroy this boat", match: :first

    assert_text "Boat was successfully destroyed"
  end
end
