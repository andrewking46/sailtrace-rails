module My
  class MembershipsController < BaseController
    def create
      @membership = Membership.new(
        user: Current.user,
        organization_type: membership_params[:organization_type],
        organization_id: membership_params[:organization_id]
      )

      if @membership.save
        redirect_back fallback_location: root_path, notice: "Joined successfully."
      else
        redirect_back fallback_location: root_path, alert: @membership.errors.full_messages.to_sentence
      end
    end

    def destroy
      @membership = Current.user.memberships.find(params[:id])
      @membership.destroy
      redirect_back fallback_location: root_path, notice: "Membership removed."
    end

    private

    def membership_params
      params.require(:membership).compact_blank.permit(:organization_type, :organization_id)
    end
  end
end
