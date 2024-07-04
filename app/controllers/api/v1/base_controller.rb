module Api
  module V1
    class BaseController < ActionController::API
      include ErrorHandler

      before_action :authenticate_user!

      private

      def authenticate_user!
        token = request.headers['Authorization']&.split(' ')&.last
        @access_token = AccessToken.find_by(token: token)

        if @access_token && @access_token.expires_at > Time.current
          @current_user = @access_token.user
        else
          render json: { error: 'Unauthorized', message: 'Token is invalid or has expired' }, status: :unauthorized
        end
      end

      def current_user
        @current_user
      end
    end
  end
end
