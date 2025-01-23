module Admin
  class BaseController < ApplicationController
    before_action :ensure_can_administer
    before_action :set_admin_breadcrumb

    private

    def set_admin_breadcrumb
      add_breadcrumb("Admin", admin_dashboard_path)
    end
  end
end
