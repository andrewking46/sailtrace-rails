class PasswordResetsController < ApplicationController
  include Authentication
  require_unauthenticated_access

  before_action :set_password_reset, only: %i[edit update]
  before_action :check_expiration, only: %i[edit update]

  def new; end

  def create
    @user = User.find_by(email_address: params[:email_address])
    if @user
      @password_reset = @user.password_resets.create(request_ip: request.remote_ip)
      if @password_reset.persisted?
        Rails.logger.info "Password reset requested for User #{@user.id} from IP #{request.remote_ip}"
        redirect_to root_url, notice: "Email sent with password reset instructions"
      else
        Rails.logger.warn "Failed password reset attempt for User #{@user.id} from IP #{request.remote_ip}: #{@password_reset.errors.full_messages.join(', ')}"
        redirect_to new_password_reset_path, alert: @password_reset.errors.full_messages.to_sentence
      end
    else
      Rails.logger.info "Password reset attempted for non-existent email: #{params[:email_address]} from IP #{request.remote_ip}"
      redirect_to root_url, notice: "If an account with that email exists, we have sent password reset instructions."
    end
  end

  def edit; end

  def update
    if params[:user][:password].empty?
      @user.errors.add(:password, "can't be empty")
      render :edit
    elsif @user.update(user_params)
      @password_reset.use!
      Rails.logger.info "Password reset successful for User #{@user.id}"
      start_new_session_for @user
      redirect_to post_authenticating_url, notice: "Password has been reset. You are now logged in."
    else
      Rails.logger.warn "Failed password reset update for User #{@user.id}: #{@user.errors.full_messages.join(', ')}"
      render :edit
    end
  end

  private

  def user_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def set_password_reset
    @password_reset = PasswordReset.pending.find_by!(reset_token: params[:reset_token])
    @user = @password_reset.user
  rescue ActiveRecord::RecordNotFound
    redirect_to new_password_reset_path, alert: "Invalid or expired password reset token."
  end

  def check_expiration
    return unless @password_reset.expired?

    Rails.logger.info "Expired password reset attempt for User #{@user.id}"
    redirect_to new_password_reset_path, alert: "Password reset has expired."
  end
end
