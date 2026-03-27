class ProcessPaymentJob < ApplicationJob
  queue_as :default

  def perform(payment_id)
    request = Payment.find_by(id: payment_id)

    unless request
      Rails.logger.error({ event: "payment_not_found", payment_id: payment_id, job_id: job_id, queue: queue_name }.to_json)
      return
    end
    Rails.logger.info({ event: "payment_processing_started", payment_id: request.id, request_uuid: request.request_uuid,
    status: request.status, retry_count: request.retry_count, job_id: job_id, queue: queue_name }.to_json)
    return if request.completed? || request.cancelled?

    request.with_lock do
      return unless request.pending? || request.failed?
      previous_status = request.status
      request.update!(status: :processing)
      Rails.logger.info({ event: "payment_status_updated", payment_id: request.id, request_uuid: request.request_uuid,
                          from_status: previous_status, to_status: "processing", retry_count: request.retry_count, job_id: job_id, queue: queue_name }.to_json)
    end
    previous_status = request.status
    PaymentProcessor.call(request)
    request.reload
    Rails.logger.info({ event: "payment_processed_successfully", payment_id: request.id, request_uuid: request.request_uuid,
                        from_status: previous_status, to_status: request.status, retry_count: request.retry_count, job_id: job_id, queue: queue_name }.to_json)
  rescue => e
    handle_failure(request, e) if request.present?
  end

  private

  def handle_failure(request, error)
    request.increment!(:retry_count)

    retry_attempt = request.retry_count
    delay = (2 ** retry_attempt)

    if retry_attempt < Payment::MAX_RETRIES
      update_payment_status(request, :failed, error)

      Rails.logger.warn({ event: "payment_retry_scheduled", payment_id: request.id, request_uuid: request.request_uuid,
                          retry_attempt: retry_attempt, next_retry_in_seconds: delay, job_id: job_id, queue: queue_name }.to_json)

      retry_job wait: delay.seconds
    else
      update_payment_status(request, :failed, error)

      Rails.logger.error({ event: "payment_permanently_failed", payment_id: request.id, request_uuid: request.request_uuid,
                           total_retries: retry_attempt, error: error.message, job_id: job_id, queue: queue_name }.to_json)
    end
  end

  def update_payment_status(request, status, error = nil)
    previous_status = request.status

    request.update!(
      status: status,
      error_message: error&.message
    )

    Rails.logger.error({ event: "payment_status_updated", payment_id: request.id, request_uuid: request.request_uuid,
                         from_status: previous_status, to_status: status, retry_count: request.retry_count, error: error&.message,
                         job_id: job_id, queue: queue_name }.to_json)
  end
end
