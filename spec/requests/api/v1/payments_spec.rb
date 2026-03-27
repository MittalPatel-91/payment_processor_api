require 'rails_helper'

RSpec.describe "Api::V1::Payments", type: :request do
  let(:headers) { { "Idempotency-Key" => SecureRandom.uuid } }

  let(:valid_params) do
    {
      amount: 100,
      currency: "INR",
      user_id: 1
    }
  end

  # CREATE
  describe "POST /api/v1/payments" do
    context "when request is valid" do
      it "creates a payment and enqueues job" do
        expect {
          post "/api/v1/payments", params: valid_params, headers: headers
        }.to change(Payment, :count).by(1)

        expect(response).to have_http_status(:accepted)

        payment = Payment.last
        expect(payment.status).to eq("pending")

        body = JSON.parse(response.body)
        expect(body["status"]).to eq("pending")
      end

      it "enqueues ProcessPaymentJob" do
        expect {
          post "/api/v1/payments", params: valid_params, headers: headers
        }.to have_enqueued_job(ProcessPaymentJob)
      end
    end

    # Idempotency: same payload
    context "when same idempotency key with same payload" do
      it "returns the same record without enqueuing job again" do
        post "/api/v1/payments", params: valid_params, headers: headers

        expect {
          post "/api/v1/payments", params: valid_params, headers: headers
        }.not_to have_enqueued_job(ProcessPaymentJob)

        expect(Payment.count).to eq(1)
      end
    end

    # Idempotency: mismatch
    context "when same idempotency key with different payload" do
      it "returns 409 conflict" do
        post "/api/v1/payments", params: valid_params, headers: headers

        post "/api/v1/payments",
             params: valid_params.merge(amount: 999),
             headers: headers

        expect(response).to have_http_status(:conflict)
      end
    end

    # Validation failure
    context "when payload is invalid" do
      it "returns 422" do
        post "/api/v1/payments", params: { amount: -10 }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when Idempotency-Key is missing" do
      it "returns 400 bad request" do
        post "/api/v1/payments", params: valid_params

        expect(response).to have_http_status(:bad_request)

        body = JSON.parse(response.body)
        expect(body["error"]).to eq("Idempotency-Key header is required")
      end
    end
  end

  # SHOW
  describe "GET /api/v1/payments/:id" do
    let(:payment) { create(:payment) }

    it "returns the payment" do
      get "/api/v1/payments/#{payment.id}"

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["id"]).to eq(payment.id)
    end

    it "returns 404 for non-existing payment" do
      get "/api/v1/payments/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  # CANCEL
  describe "POST /api/v1/payments/:id/cancel" do
    context "when payment is pending" do
      let(:payment) { create(:payment, status: "pending") }

      it "cancels the payment" do
        post "/api/v1/payments/#{payment.id}/cancel"

        expect(response).to have_http_status(:ok)

        payment.reload
        expect(payment.status).to eq("cancelled")
      end
    end

    context "when payment is processing" do
      let(:payment) { create(:payment, status: "processing") }

      it "returns 409 conflict" do
        post "/api/v1/payments/#{payment.id}/cancel"

        expect(response).to have_http_status(:conflict)

        payment.reload
        expect(payment.status).to eq("processing")
      end
    end

    context "when payment is failed (retry pending)" do
      let(:payment) { create(:payment, status: "failed", retry_count: 1) }

      it "returns 409 conflict" do
        post "/api/v1/payments/#{payment.id}/cancel"

        expect(response).to have_http_status(:conflict)

        payment.reload
        expect(payment.status).to eq("failed")
      end
    end

    context "when payment is completed" do
      let(:payment) { create(:payment, status: "completed") }

      it "returns 409 conflict" do
        post "/api/v1/payments/#{payment.id}/cancel"

        expect(response).to have_http_status(:conflict)
      end
    end

    context "when payment is already cancelled" do
      let(:payment) { create(:payment, status: "cancelled") }

      it "returns 409 conflict" do
        post "/api/v1/payments/#{payment.id}/cancel"

        expect(response).to have_http_status(:conflict)

        payment.reload
        expect(payment.status).to eq("cancelled")
      end
    end
  end
end
