module UserOwnedResource
  extend ActiveSupport::Concern

  included do
    before_action :authorize_user_resource, only: %i[show update destroy]
  end

  private

  def authorize_user_resource
    resource_name = controller_name.singularize
    resource_id = params[:id]
    resource = current_user.send(controller_name).find_by(id: resource_id)

    if resource.nil?
      render json: { error: "#{resource_name.capitalize} not found" }, status: :not_found
    elsif resource.user_id != current_user.id
      render json: { error: "You are not authorized to perform this action" }, status: :forbidden
    else
      instance_variable_set("@#{resource_name}", resource)
    end
  end
end
