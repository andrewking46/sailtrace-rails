class ApplicationController < ActionController::Base
  include Authorization
  include Authentication
  include Breadcrumbable

  before_action :set_default_breadcrumb

  layout "application"

  private

  def set_default_breadcrumb
    add_breadcrumb("Home", root_path) if signed_in?
  end
end
