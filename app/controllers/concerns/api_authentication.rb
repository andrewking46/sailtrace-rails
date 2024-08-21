module ApiAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user_agent
    before_action :authenticate_user!
  end

  private

  def authenticate_user_agent
    user_agent = request.user_agent
    return if user_agent&.start_with?("SailTrace/")

    render json: { error: "Invalid User-Agent" }, status: :unauthorized
  end

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last
    @access_token = AccessToken.find_by(token:)

    if @access_token && @access_token.expires_at > Time.current
      @current_user = @access_token.user
    else
      render json: { error: "Unauthorized", message: "Token is invalid or has expired" }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end
end
