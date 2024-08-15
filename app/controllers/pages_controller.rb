class PagesController < ApplicationController
  require_unauthenticated_access only: [ :index ]
  allow_unauthenticated_access only: [ :privacy ]

  def index; end
  def more; end
  def privacy; end

  def styleguide
    @user = Current.user
  end
end
