require "application_system_test_case"

class BoatClassesTest < ApplicationSystemTestCase
  setup do
    @boat_class = boat_classes(:one)
  end

  test "visiting the index" do
    visit boat_classes_url
    assert_selector "h1", text: "Boat classes"
  end

  test "should create boat class" do
    visit boat_classes_url
    click_on "New boat class"

    check "Is one design" if @boat_class.is_one_design
    fill_in "Name", with: @boat_class.name
    click_on "Create Boat class"

    assert_text "Boat class was successfully created"
    click_on "Back"
  end

  test "should update Boat class" do
    visit boat_class_url(@boat_class)
    click_on "Edit this boat class", match: :first

    check "Is one design" if @boat_class.is_one_design
    fill_in "Name", with: @boat_class.name
    click_on "Update Boat class"

    assert_text "Boat class was successfully updated"
    click_on "Back"
  end

  test "should destroy Boat class" do
    visit boat_class_url(@boat_class)
    click_on "Destroy this boat class", match: :first

    assert_text "Boat class was successfully destroyed"
  end
end
