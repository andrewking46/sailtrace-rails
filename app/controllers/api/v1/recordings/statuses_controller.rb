module Api
  module V1
    module Recordings
      class StatusesController < BaseController
        def show
          render json: {
            status: @recording.status,
            message: status_message(@recording.status)
          }
        end

        private

        def status_message(status)
          case status
          when :not_started then "Recording not started..."
          when :in_progress then "Recording in progress..."
          when :processing then "Processing your recording..."
          when :processed then "Processing completed"
          else "Unknown status"
          end
        end
      end
    end
  end
end
