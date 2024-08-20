require "test_helper"

class GPS::DistanceCalculatorTest < ActiveSupport::TestCase
  test "calculates distance correctly" do
    # Test case 1: Short distance
    lat1 = 40.6892
    lon1 = -74.0445 # Statue of Liberty
    lat2 = 40.7484
    lon2 = -73.9857 # Empire State Building
    expected_distance = 8443.47 # meters
    calculated_distance = GPS::DistanceCalculator.distance_in_meters(lat1, lon1, lat2, lon2)
    assert_in_delta expected_distance, calculated_distance, 10, "Short distance calculation is off"

    # Test case 2: Long distance
    lat1 = 40.7128
    lon1 = -74.0060 # New York City
    lat2 = 51.5074
    lon2 = -0.1278 # London
    expected_distance = 5_570_226.0 # meters
    calculated_distance = GPS::DistanceCalculator.distance_in_meters(lat1, lon1, lat2, lon2)
    assert_in_delta expected_distance, calculated_distance, 1000, "Long distance calculation is off"

    # Test case 3: Same point
    lat = 40.7128
    lon = -74.0060
    assert_equal 0, GPS::DistanceCalculator.distance_in_meters(lat, lon, lat, lon), "Distance to self should be 0"

    # Test case 4: Invalid coordinates
    assert_equal 0, GPS::DistanceCalculator.distance_in_meters(nil, nil, 0, 0), "Invalid coordinates should return 0"
  end
end
