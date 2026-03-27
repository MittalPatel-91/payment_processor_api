class Payment < ApplicationRecord
  after_update :log_status_transition
  before_validation :set_payload_hash, if: -> { payload.present? }
  # Constant & ENUM
  MAX_RETRIES = 3

  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed",
    cancelled: "cancelled"
  }

  # validations
  validates :request_uuid, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :payload, presence: true
  validates :payload_hash, presence: true
  validate :validate_payload_fields
  validate :payload_hash_matches_payload

  def cancellable?
    status == "pending"
  end

  def log_status_transition
    return unless saved_change_to_status?

    Rails.logger.info({
      event: "payment_status_changed",
      payment_id: id,
      request_uuid: request_uuid,
      from_status: saved_change_to_status[0],
      to_status: saved_change_to_status[1],
      retry_count: retry_count
    }.to_json)
  end

  private

  def validate_payload_fields
    return if payload.blank?

    # Required fields
    errors.add(:payload, "amount is required") unless payload["amount"].present?
    errors.add(:payload, "currency is required") unless payload["currency"].present?
    errors.add(:payload, "user_id is required") unless payload["user_id"].present?

    # Amount validation
    if payload["amount"].present? && payload["amount"].to_f <= 0
      errors.add(:payload, "amount must be greater than 0")
    end

    # Currency format validation (ISO 3-letter)
    if payload["currency"].present? && payload["currency"] !~ /\A[A-Z]{3}\z/
      errors.add(:payload, "currency must be a valid 3-letter ISO code")
    end
  end

  def set_payload_hash
    self.payload_hash = Digest::SHA256.hexdigest(payload.to_json)
  end

  def payload_hash_matches_payload
    return if payload.blank? || payload_hash.blank?

    expected_hash = Digest::SHA256.hexdigest(payload.to_json)

    if payload_hash != expected_hash
      errors.add(:payload_hash, "does not match payload")
    end
  end
end
