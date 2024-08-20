class ApplicationController < ActionController::Base
  include Authorization
  include Authentication

  before_action :authorize_mini_profiler
end
