class UsersController < ApplicationController
  require_unauthenticated_access

  def new
    @user = User.new
  end

  def create
    @user = User.create!(user_params)
    start_new_session_for @user
    redirect_to recordings_url
  rescue ActiveRecord::RecordNotUnique
    redirect_to new_session_url(email_address: user_params[:email_address])
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :username, :email_address, :password,
                                 :password_confirmation)
  end
end
