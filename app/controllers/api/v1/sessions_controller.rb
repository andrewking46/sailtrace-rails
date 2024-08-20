module Api
  module V1
    class SessionsController < BaseController
      skip_before_action :authenticate_user!, only: %i[create refresh]

      def create
        user = User.find_by(email_address: params[:email])
        if user&.authenticate(params[:password])
          token = user.access_tokens.create!
          render json: { access_token: token.token, refresh_token: token.refresh_token, expires_at: token.expires_at }
        else
          # Mimic the response time of a successful login
          sleep(rand(500..1499) / 1000.0) # Sleep for 500-1500ms
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def refresh
        token = AccessToken.find_by(refresh_token: params[:refresh_token])
        if token && token.refresh_token_expires_at > Time.current
          old_token = token
          new_token = token.user.access_tokens.create!
          old_token.destroy
          render json: { access_token: new_token.token, refresh_token: new_token.refresh_token,
                         expires_at: new_token.expires_at }
        else
          render json: { error: "Invalid or expired refresh token" }, status: :unauthorized
        end
      end

      def destroy
        @access_token.destroy if @access_token
        head :no_content
      end
    end
  end
end
