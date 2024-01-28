require "application_system_test_case"

class RecordedLocationsTest < ApplicationSystemTestCase
  setup do
    @recorded_location = recorded_locations(:one)
  end

  test "visiting the index" do
    visit recorded_locations_url
    assert_selector "h1", text: "Recorded locations"
  end

  test "should create recorded location" do
    visit recorded_locations_url
    click_on "New recorded location"

    fill_in "Heading", with: @recorded_location.heading
    fill_in "Latitude", with: @recorded_location.latitude
    fill_in "Longitude", with: @recorded_location.longitude
    fill_in "Recording", with: @recorded_location.recording_id
    fill_in "Velocity", with: @recorded_location.velocity
    click_on "Create Recorded location"

    assert_text "Recorded location was successfully created"
    click_on "Back"
  end

  test "should update Recorded location" do
    visit recorded_location_url(@recorded_location)
    click_on "Edit this recorded location", match: :first

    fill_in "Heading", with: @recorded_location.heading
    fill_in "Latitude", with: @recorded_location.latitude
    fill_in "Longitude", with: @recorded_location.longitude
    fill_in "Recording", with: @recorded_location.recording_id
    fill_in "Velocity", with: @recorded_location.velocity
    click_on "Update Recorded location"

    assert_text "Recorded location was successfully updated"
    click_on "Back"
  end

  test "should destroy Recorded location" do
    visit recorded_location_url(@recorded_location)
    click_on "Destroy this recorded location", match: :first

    assert_text "Recorded location was successfully destroyed"
  end
end
