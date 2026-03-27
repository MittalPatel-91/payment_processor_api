class Api::V1::PaymentsController < ApplicationController
  def create
    uuid = request.headers["Idempotency-Key"]
    uuid ||= SecureRandom.uuid
    Rails.logger.info({ event: "payment_request_received", request_uuid: uuid, payload: payment_params }.to_json)

    payment = IdempotencyHandler.find_or_create!(uuid, payment_params)

    if payment.pending?
      ProcessPaymentJob.perform_later(payment.id)
    end

    render json: payment, status: :accepted
  end

  def show
    request = Payment.find(params[:id])
    render json: request
  end

  def cancel
    payment = Payment.find(params[:id])

    payment.with_lock do
      unless payment.cancellable?
        return render json: {
          error: "Payment cannot be cancelled in '#{payment.status}' state"
        }, status: :conflict
      end

      payment.update!(status: :cancelled)
    end

    render json: payment, status: :ok
  end

  private

  def payment_params
    params.permit(:amount, :currency, :user_id)
  end
end
