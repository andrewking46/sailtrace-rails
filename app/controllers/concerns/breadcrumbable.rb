module Breadcrumbable
  extend ActiveSupport::Concern

  included do
    helper_method :breadcrumbs
  end

  def add_breadcrumb(name, path = nil)
    @breadcrumbs ||= []
    @breadcrumbs << [ name, path ]
  end

  def breadcrumbs
    @breadcrumbs || []
  end
end
