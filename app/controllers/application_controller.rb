class ApplicationController < ActionController::API
  rescue_from IdempotencyConflictError, with: :handle_idempotency_conflict
  rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found

  private

  def handle_idempotency_conflict(exception)
    render json: {
      error: exception.message
    }, status: :conflict
  end

  def handle_record_invalid(exception)
    render json: {
      errors: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def handle_not_found(exception)
    render json: {
      errors: exception.message
    }, status: :not_found
  end
end
