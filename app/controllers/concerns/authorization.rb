module Authorization
  extend ActiveSupport::Concern

  included do
    before_action :authorize_mini_profiler
  end

  private
    def ensure_can_administer
      head :forbidden unless Current.user.is_admin?
    end

    def authorize_mini_profiler
      if Current.user && Current.user.is_admin?
        Rack::MiniProfiler.authorize_request
      end
    end
end
