module ErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActionController::ParameterMissing, with: :bad_request
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  end

  private

  def not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end

  def bad_request(exception)
    render json: { error: exception.message }, status: :bad_request
  end

  def unprocessable_entity(exception)
    render json: { errors: exception.record.errors }, status: :unprocessable_entity
  end
end
