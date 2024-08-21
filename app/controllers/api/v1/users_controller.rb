module Api
  module V1
    class UsersController < BaseController
      skip_before_action :authenticate_user!, only: [ :create ]
      before_action :set_user, only: [ :show, :update, :destroy ]
      before_action :ensure_current_user, only: [ :update, :destroy ]

      def show
        render json: @user, serializer: UserSerializer
      end

      def create
        @user = User.new(user_params)
        if @user.save
          token = @user.access_tokens.create!
          render json: {
            user: UserSerializer.new(@user),
            access_token: token.token,
            refresh_token: token.refresh_token,
            expires_at: token.expires_at
          }, status: :created
        else
          render json: { errors: @user.errors }, status: :unprocessable_entity
        end
      end

      def update
        if @user.update(user_params)
          render json: @user, serializer: UserSerializer
        else
          render json: { errors: @user.errors }, status: :unprocessable_entity
        end
      end

      def destroy
        if @user.destroy
          head :no_content
        else
          render json: { errors: @user.errors }, status: :unprocessable_entity
        end
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def ensure_current_user
        unless @user == current_user
          render json: { error: "You can only modify your own account" }, status: :forbidden
        end
      end

      def user_params
        params.require(:user).permit(:first_name, :last_name, :username, :email_address, :password, :password_confirmation, :phone_number, :country, :time_zone)
      end
    end
  end
end
