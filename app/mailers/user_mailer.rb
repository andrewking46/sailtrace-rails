class UserMailer < ApplicationMailer
  def password_reset(user, reset_token)
    @user = user
    @reset_url = edit_password_reset_url(reset_token: reset_token)
    mail to: user.email_address, subject: 'Password reset instructions'
  end
end
