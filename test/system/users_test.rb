require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "visiting the index" do
    visit users_url
    assert_selector "h1", text: "Users"
  end

  test "should create user" do
    visit users_url
    click_on "New user"

    fill_in "Country", with: @user.country
    fill_in "Date of birth", with: @user.date_of_birth
    fill_in "Email address", with: @user.email_address
    fill_in "First name", with: @user.first_name
    check "Is admin" if @user.is_admin
    fill_in "Last name", with: @user.last_name
    fill_in "Phone number", with: @user.phone_number
    fill_in "Time zone", with: @user.time_zone
    fill_in "Username", with: @user.username
    click_on "Create User"

    assert_text "User was successfully created"
    click_on "Back"
  end

  test "should update User" do
    visit user_url(@user)
    click_on "Edit this user", match: :first

    fill_in "Country", with: @user.country
    fill_in "Date of birth", with: @user.date_of_birth
    fill_in "Email address", with: @user.email_address
    fill_in "First name", with: @user.first_name
    check "Is admin" if @user.is_admin
    fill_in "Last name", with: @user.last_name
    fill_in "Phone number", with: @user.phone_number
    fill_in "Time zone", with: @user.time_zone
    fill_in "Username", with: @user.username
    click_on "Update User"

    assert_text "User was successfully updated"
    click_on "Back"
  end

  test "should destroy User" do
    visit user_url(@user)
    click_on "Destroy this user", match: :first

    assert_text "User was successfully destroyed"
  end
end
