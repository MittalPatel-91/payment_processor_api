FactoryBot.define do
  factory :payment do
    request_uuid { SecureRandom.uuid }
    status { "pending" }

    payload do
      {
        "amount" => 100,
        "currency" => "INR",
        "user_id" => 1
      }
    end

    payload_hash { Digest::SHA256.hexdigest(payload.to_json) }
    retry_count { 0 }
  end
end
