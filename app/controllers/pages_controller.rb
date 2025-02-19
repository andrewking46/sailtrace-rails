class PagesController < ApplicationController
  layout "marketing", only: [:index, :privacy]

  require_unauthenticated_access only: [ :index ]
  allow_unauthenticated_access only: [ :privacy ]

  def index
    @app_store_qr_code = RQRCode::QRCode.new('https://www.sailtrace.app')
  end
  def more; end
  def privacy; end

  def styleguide
    @user = Current.user
  end
end
