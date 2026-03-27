require 'rails_helper'

RSpec.describe ProcessPaymentJob, type: :job do
  let(:payment) { create(:payment, status: "pending", retry_count: 0) }

  describe "#perform" do
    # Success case
    context "when payment exists and processing succeeds" do
      before do
        allow(PaymentProcessor).to receive(:call) do |req|
          req.update!(status: :completed)
        end
      end

      it "processes payment and marks it as completed" do
        described_class.perform_now(payment.id)

        payment.reload
        expect(payment.status).to eq("completed")
        expect(PaymentProcessor).to have_received(:call).with(payment)
      end
    end

    # Missing record
    context "when payment does not exist" do
      it "logs error and exits gracefully" do
        expect(Rails.logger).to receive(:error) do |log|
          parsed = JSON.parse(log)
          expect(parsed["event"]).to eq("payment_not_found")
          expect(parsed["payment_id"]).to eq(99999)
        end

        described_class.perform_now(99999)
      end
    end

    # Already completed
    context "when payment is already completed" do
      let(:payment) { create(:payment, status: "completed") }

      it "does not process again" do
        expect(PaymentProcessor).not_to receive(:call)

        described_class.perform_now(payment.id)
      end
    end

    context "when payment is cancelled" do
      let(:payment) { create(:payment, status: "cancelled") }

      it "does not process again" do
        expect(PaymentProcessor).not_to receive(:call)

        described_class.perform_now(payment.id)
      end
    end

    # Retry case
    context "when processor raises error and retry is allowed" do
      before do
        allow(PaymentProcessor).to receive(:call).and_raise("Some error")
      end

      it "increments retry_count, resets status, and retries job" do
        expect_any_instance_of(ProcessPaymentJob).to receive(:retry_job).with(wait: 2.seconds)

        described_class.perform_now(payment.id)

        payment.reload
        expect(payment.retry_count).to eq(1)
        expect(payment.status).to eq("failed")
        expect(payment.error_message).to eq("Some error")
      end
    end

    # Retry state fix test (NEW)
    context "when retrying after failure" do
      it "resets status to failed so retry can proceed" do
        payment = create(:payment, status: "processing", retry_count: 0)

        job = described_class.new

        allow(job).to receive(:retry_job)

        job.send(:handle_failure, payment, StandardError.new("error"))

        payment.reload
        expect(payment.status).to eq("failed")
      end
    end

    # Final failure
    context "when retries are exhausted" do
      let(:payment) { create(:payment, status: "pending", retry_count: Payment::MAX_RETRIES - 1) }

      before do
        allow(PaymentProcessor).to receive(:call).and_raise("Final failure")
      end

      it "marks payment as failed" do
        described_class.perform_now(payment.id)

        payment.reload
        expect(payment.status).to eq("failed")
        expect(payment.error_message).to eq("Final failure")
      end
    end
  end
end
