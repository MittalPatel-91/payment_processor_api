class IdempotencyHandler
  def self.find_or_create!(uuid, payload)
    payment = Payment.find_by(request_uuid: uuid)

    if payment.present?
      if payment.payload != payload
        raise IdempotencyConflictError, "Payload mismatch for same Idempotency-Key: #{uuid}"
      end

      return payment
    end

    Payment.create!(
      request_uuid: uuid,
      payload: payload,
      status: :pending
    )
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
