class PagesController < ApplicationController
  require_unauthenticated_access only: [ :index ]

  def index; end
  def more; end
end
