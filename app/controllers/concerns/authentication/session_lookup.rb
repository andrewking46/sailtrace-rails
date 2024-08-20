module Authentication::SessionLookup
  def find_session_by_cookie
    return unless token = cookies.signed[:session_token]

    Session.find_by(token:)
  end
end
