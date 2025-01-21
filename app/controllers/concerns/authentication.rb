module Authentication
  extend ActiveSupport::Concern
  include SessionLookup

  included do
    before_action :require_authentication
    helper_method :signed_in?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :attempt_authentication, **options
    end

    def require_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :restore_authentication, :redirect_signed_in_user_to_default_url, **options
    end
  end

  private

  def signed_in?
    Current.user.present?
  end

  def require_authentication
    restore_authentication || request_authentication
  end

  def attempt_authentication
    restore_authentication
  end

  def restore_authentication
    if session = find_session_by_cookie
      resume_session session
      true
    else
      false
    end
  end

  def request_authentication
    session[:return_to_after_authenticating] = request.url
    redirect_to new_session_url
  end

  def redirect_signed_in_user_to_default_url
    redirect_to my_recordings_url if signed_in?
  end

  def start_new_session_for(user)
    user.sessions.start!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
      authenticated_as session
    end
  end

  def resume_session(session)
    session.resume user_agent: request.user_agent, ip_address: request.remote_ip
    authenticated_as session
  end

  def authenticated_as(session)
    Current.user = session.user
    cookies.signed.permanent[:session_token] = { value: session.token, httponly: true, same_site: :lax }
  end

  def post_authenticating_url
    session.delete(:return_to_after_authenticating) || my_recordings_url
  end

  def reset_authentication
    cookies.delete(:session_token)
    Current.user = nil
  end
end
