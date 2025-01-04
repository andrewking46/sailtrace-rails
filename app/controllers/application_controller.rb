class ApplicationController < ActionController::Base
  include Authorization
  include Authentication
end
