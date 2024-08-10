module UserOwnedResource
  extend ActiveSupport::Concern

  included do
    before_action :authorize_user_resource, only: [:show, :update, :destroy]
  end

  private

  def authorize_user_resource
    resource = instance_variable_get("@#{controller_name.singularize}")
    if resource.nil?
      render json: { error: 'Resource not found' }, status: :not_found
    elsif resource.user_id != current_user.id
      render json: { error: 'You are not authorized to perform this action' }, status: :forbidden
    end
  end
end
