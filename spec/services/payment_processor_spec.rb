require 'rails_helper'

RSpec.describe PaymentProcessor do
  let(:payment) { create(:payment, status: "processing") }

  describe ".call" do
    context "when processing succeeds" do
      it "updates payment status to completed" do
        described_class.call(payment, random: 0.5)

        payment.reload
        expect(payment.status).to eq("completed")
      end

      it "adds response with transaction_id" do
        described_class.call(payment, random: 0.5)

        payment.reload
        expect(payment.response).to include("transaction_id")
        expect(payment.response["status"]).to eq("success")
      end
    end

    context "when external API fails" do
      it "raises an error" do
        expect {
          described_class.call(payment, random: 0.1)
        }.to raise_error(RuntimeError, "Payment gateway timeout")
      end

      it "does not update payment status or response" do
        expect {
          described_class.call(payment, random: 0.1)
        }.to raise_error(RuntimeError)

        payment.reload
        expect(payment.status).to eq("processing")
        expect(payment.response).to eq({})
      end
    end
  end
end
