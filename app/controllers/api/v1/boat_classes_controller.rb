module Api
  module V1
    class BoatClassesController < BaseController
      def index
        @boat_classes = BoatClass.all.order(:name)
        render json: @boat_classes, each_serializer: BoatClassSerializer
      end
    end
  end
end
