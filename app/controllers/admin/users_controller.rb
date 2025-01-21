module Admin
  class UsersController < BaseController
    before_action :set_user, only: [ :show, :destroy ]

    def index
      @users = User.all.order(last_name: :asc, first_name: :asc)
    end

    def show
    end

    def destroy
      @user.destroy!
      redirect_to admin_users_path, notice: "User deleted"
    end

    private

    def set_user
      @user = User.find(params[:id])
    end
  end
end
