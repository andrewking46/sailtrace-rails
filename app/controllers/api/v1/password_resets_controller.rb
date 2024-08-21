module Api
  module V1
    class PasswordResetsController < BaseController
      skip_before_action :authenticate_user!

      def create
        user = User.find_by(email_address: params[:email_address])
        password_reset = user&.password_resets&.create(request_ip: request.remote_ip)

        if password_reset&.persisted?
          render_success("Password reset instructions sent to your email")
        else
          render_error(password_reset&.errors&.full_messages || [ "Unable to process request" ], :unprocessable_entity)
        end
      end

      def update
        password_reset = PasswordReset.find_by_token(params[:reset_token])

        if password_reset.nil?
          render_error("Invalid or expired reset token", :unprocessable_entity)
        elsif password_reset.expired?
          render_error("Reset token has expired", :unprocessable_entity)
        elsif password_reset.update_password(password_params)
          render_success("Password has been reset successfully")
        else
          render_error(password_reset.errors.full_messages, :unprocessable_entity)
        end
      end

      private

      def password_params
        params.permit(:password, :password_confirmation)
      end

      def render_success(message)
        render json: { message: message }, status: :ok
      end

      def render_error(errors, status)
        render json: { errors: Array(errors) }, status: status
      end
    end
  end
end
