class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new; end

  def create
    if user = User.authenticate_by(session_params)
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

  def session_params
    params.require(:session).permit(:email_address, :password)
  end

  def render_rejection(status)
    flash.now[:alert] = "Not authorized"
    render :new, status:
  end
end
