require "rails_helper"

RSpec.describe Payment, type: :model do
  let(:valid_payload) do
    {
      "amount" => 100,
      "currency" => "INR",
      "user_id" => 1
    }
  end

  subject { build(:payment) }

  # Validations
  describe "validations" do
    it "is valid with valid attributes" do
      expect(subject).to be_valid
    end

    it "is invalid without request_uuid" do
      subject.request_uuid = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:request_uuid]).to include("can't be blank")
    end

    it "is invalid with duplicate request_uuid" do
      create(:payment, request_uuid: subject.request_uuid)

      expect(subject).not_to be_valid
      expect(subject.errors[:request_uuid]).to include("has already been taken")
    end

    it "is invalid without payload" do
      subject.payload = nil
      expect(subject).not_to be_valid
    end

    it "auto-generates correct payload_hash from payload" do
      subject.payload_hash = nil

      subject.valid?

      expected_hash = Digest::SHA256.hexdigest(subject.payload.to_json)
      expect(subject.payload_hash).to eq(expected_hash)
    end

    it "raises error for invalid status" do
      expect {
        subject.status = "invalid"
      }.to raise_error(ArgumentError, /is not a valid status/)
    end

    it "is invalid when payload_hash does not match payload" do
      subject.payload_hash = "invalid_hash"

      allow(subject).to receive(:set_payload_hash)

      expect(subject).not_to be_valid
      expect(subject.errors[:payload_hash]).to include("does not match payload")
    end
  end

  # Payload Validations
  describe "#validate_payload_fields" do
    it "is invalid when amount is missing" do
      subject.payload.delete("amount")

      expect(subject).not_to be_valid
      expect(subject.errors[:payload]).to include("amount is required")
    end

    it "is invalid when currency is missing" do
      subject.payload.delete("currency")
      expect(subject).not_to be_valid
      expect(subject.errors[:payload]).to include("currency is required")
    end

    it "is invalid when user_id is missing" do
      subject.payload.delete("user_id")
      expect(subject).not_to be_valid
      expect(subject.errors[:payload]).to include("user_id is required")
    end

    it "is invalid when amount is <= 0" do
      subject.payload["amount"] = 0
      expect(subject).not_to be_valid
      expect(subject.errors[:payload]).to include("amount must be greater than 0")
    end

    it "is invalid with incorrect currency format" do
      subject.payload["currency"] = "inr"
      expect(subject).not_to be_valid
      expect(subject.errors[:payload]).to include("currency must be a valid 3-letter ISO code")
    end
  end

  # Enum
  describe "status enum" do
    it "defines all expected statuses" do
      expect(described_class.statuses.keys).to contain_exactly(
        "pending", "processing", "completed", "failed", "cancelled"
      )
    end
  end

  # Business Logic
  describe "#cancellable?" do
    it "returns true when status is pending" do
      subject.status = "pending"
      expect(subject.cancellable?).to be true
    end

    it "returns false when status is completed" do
      subject.status = "completed"
      expect(subject.cancellable?).to be false
    end

    it "returns false when status is processing" do
      subject.status = "processing"
      expect(subject.cancellable?).to be false
    end

    it "returns false when status is failed" do
      subject.status = "failed"
      expect(subject.cancellable?).to be false
    end
  end

  describe "#log_status_transition" do
    it "logs status change" do
      payment = create(:payment, status: "pending")

      expect(Rails.logger).to receive(:info) do |log|
        parsed = JSON.parse(log)
        expect(parsed["event"]).to eq("payment_status_changed")
        expect(parsed["from_status"]).to eq("pending")
        expect(parsed["to_status"]).to eq("completed")
      end

      payment.update!(status: "completed")
    end
  end
end
