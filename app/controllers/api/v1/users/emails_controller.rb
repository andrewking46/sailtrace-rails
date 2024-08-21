module Api
  module V1
    module Users
      class EmailsController < BaseController
        skip_before_action :authenticate_user!, only: [ :show ]

        def show
          email = params[:email]&.downcase

          unless email.present? && email =~ URI::MailTo::EMAIL_REGEXP
            render json: { error: "Invalid email format" }, status: :unprocessable_entity
            return
          end

          user_exists = User.exists?(email_address: email)

          render json: { exists: user_exists }, status: :ok
        end
      end
    end
  end
end
