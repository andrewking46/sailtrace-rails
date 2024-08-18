class ApplicationController < ActionController::Base
  include Authentication, Authorization

  before_action :authorize_mini_profiler
end
