module Authorization
  private

  def ensure_can_administer
    head :forbidden unless Current.user.is_admin?
  end

  def authorize_mini_profiler
    return unless Current.user && Current.user.is_admin?

    Rack::MiniProfiler.authorize_request
  end
end
