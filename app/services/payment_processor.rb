class PaymentProcessor
  def self.call(request, random: rand)
    # Simulate failure (real-world external API behavior)
    raise "Payment gateway timeout" if random < 0.3

    response = {
      transaction_id: SecureRandom.hex(10),
      status: "success"
    }

    request.update!(
      status: :completed,
      response: response
    )
  end
end
