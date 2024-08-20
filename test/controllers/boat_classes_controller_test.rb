require "test_helper"

class BoatClassesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @boat_class = boat_classes(:one)
  end

  test "should get index" do
    get boat_classes_url
    assert_response :success
  end

  test "should get new" do
    get new_boat_class_url
    assert_response :success
  end

  test "should create boat_class" do
    assert_difference("BoatClass.count") do
      post boat_classes_url,
           params: { boat_class: { is_one_design: @boat_class.is_one_design, name: @boat_class.name } }
    end

    assert_redirected_to boat_class_url(BoatClass.last)
  end

  test "should show boat_class" do
    get boat_class_url(@boat_class)
    assert_response :success
  end

  test "should get edit" do
    get edit_boat_class_url(@boat_class)
    assert_response :success
  end

  test "should update boat_class" do
    patch boat_class_url(@boat_class),
          params: { boat_class: { is_one_design: @boat_class.is_one_design, name: @boat_class.name } }
    assert_redirected_to boat_class_url(@boat_class)
  end

  test "should destroy boat_class" do
    assert_difference("BoatClass.count", -1) do
      delete boat_class_url(@boat_class)
    end

    assert_redirected_to boat_classes_url
  end
end
