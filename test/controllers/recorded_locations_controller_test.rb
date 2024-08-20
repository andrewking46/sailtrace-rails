require "test_helper"

class RecordedLocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @recorded_location = recorded_locations(:one)
  end

  test "should get index" do
    get recorded_locations_url
    assert_response :success
  end

  test "should get new" do
    get new_recorded_location_url
    assert_response :success
  end

  test "should create recorded_location" do
    assert_difference("RecordedLocation.count") do
      post recorded_locations_url,
           params: { recorded_location: { heading: @recorded_location.heading, latitude: @recorded_location.latitude,
                                          longitude: @recorded_location.longitude, recording_id: @recorded_location.recording_id, velocity: @recorded_location.velocity } }
    end

    assert_redirected_to recorded_location_url(RecordedLocation.last)
  end

  test "should show recorded_location" do
    get recorded_location_url(@recorded_location)
    assert_response :success
  end

  test "should get edit" do
    get edit_recorded_location_url(@recorded_location)
    assert_response :success
  end

  test "should update recorded_location" do
    patch recorded_location_url(@recorded_location),
          params: { recorded_location: { heading: @recorded_location.heading, latitude: @recorded_location.latitude,
                                         longitude: @recorded_location.longitude, recording_id: @recorded_location.recording_id, velocity: @recorded_location.velocity } }
    assert_redirected_to recorded_location_url(@recorded_location)
  end

  test "should destroy recorded_location" do
    assert_difference("RecordedLocation.count", -1) do
      delete recorded_location_url(@recorded_location)
    end

    assert_redirected_to recorded_locations_url
  end
end
