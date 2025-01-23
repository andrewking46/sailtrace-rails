module My
  module Recordings
    class SpeedMapsController < BaseController
      def show
        add_breadcrumb("Speed map")
      end
    end
  end
end
