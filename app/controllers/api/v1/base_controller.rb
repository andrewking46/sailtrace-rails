module Api
  module V1
    class BaseController < ActionController::API
      include ErrorHandler
      include ApiAuthentication
    end
  end
end
