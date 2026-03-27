require 'rails_helper'

RSpec.describe IdempotencyHandler do
  let(:uuid) { SecureRandom.uuid }

  let(:payload) do
    {
      "amount" => 100,
      "currency" => "INR",
      "user_id" => 1
    }
  end

  let(:payload_hash) { Digest::SHA256.hexdigest(payload.to_json) }

  describe ".find_or_create!" do
    context "when no existing record" do
      it "creates a new payment" do
        expect {
          described_class.find_or_create!(uuid, payload)
        }.to change(Payment, :count).by(1)

        payment = Payment.last
        expect(payment.request_uuid).to eq(uuid)
        expect(payment.payload).to eq(payload)
        expect(payment.payload_hash).to eq(payload_hash)
        expect(payment.status).to eq("pending")
      end
    end

    context "when record exists with same payload" do
      let!(:existing_payment) do
        create(:payment,
          request_uuid: uuid,
          payload: payload
        )
      end

      it "returns the existing payment" do
        result = described_class.find_or_create!(uuid, payload)

        expect(result).to eq(existing_payment)
        expect(Payment.count).to eq(1)
      end
    end

    context "when record exists with different payload" do
      let!(:existing_payment) do
        create(:payment,
          request_uuid: uuid,
          payload: payload
        )
      end

      let(:different_payload) do
        payload.merge("amount" => 999)
      end

      it "raises IdempotencyConflictError" do
        expect {
          described_class.find_or_create!(uuid, different_payload)
        }.to raise_error(IdempotencyConflictError, /Payload mismatch/)
      end
    end

    context "when RecordNotUnique occurs" do
      it "retries and succeeds" do
        call_count = 0

        allow(Payment).to receive(:create!).and_wrap_original do |method, *args|
          call_count += 1
          raise ActiveRecord::RecordNotUnique if call_count == 1
          method.call(*args)
        end

        expect {
          described_class.find_or_create!(uuid, payload)
        }.to change(Payment, :count).by(1)
      end
    end
  end
end
