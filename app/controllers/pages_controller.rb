class PagesController < ApplicationController
  require_unauthenticated_access only: [ :index ]

  def index; end
  def more; end

  def styleguide
    @user = Current.user
  end
end
