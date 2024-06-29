class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  def new
  end

  def create
    if user = User.authenticate_by(email_address: params[:email_address], password: params[:password])
      start_new_session_for user
      redirect_to post_authenticating_url
    else
      render_rejection :unauthorized
    end
  end

  def destroy
    reset_authentication
    redirect_to root_url
  end

  private
    def render_rejection(status)
      flash.now[:alert] = "Not authorized"
      render :new, status: status
    end
end
