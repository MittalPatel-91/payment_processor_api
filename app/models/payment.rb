class Payment < ApplicationRecord
  MAX_RETRIES = 3

  enum status: {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed",
    cancelled: "cancelled"
  }

  validates :request_uuid, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: statuses.keys }
end
