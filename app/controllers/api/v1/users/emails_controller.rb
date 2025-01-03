module Api
  module V1
    module Users
      class EmailsController < BaseController
        skip_before_action :authenticate_user!, only: [ :show ]

        def show
          email = params[:email]&.downcase
          Rails.logger.info "Received email parameter: #{email}"

          unless email.present? && email =~ URI::MailTo::EMAIL_REGEXP
            render json: { error: "Invalid email format" }, status: :unprocessable_entity
            return
          end

          user_exists = User.exists?(email_address: email)
          Rails.logger.info "User exists check result: #{user_exists}"

          render json: { exists: user_exists }, status: :ok
        end
      end
    end
  end
end
