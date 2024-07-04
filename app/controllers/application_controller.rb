class ApplicationController < ActionController::Base
  include Authentication, Authorization
end
