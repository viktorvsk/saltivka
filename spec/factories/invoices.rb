FactoryBot.define do
  factory :invoice do
    author
    amount_sats { rand(21000000) }
    order_id { SecureRandom.hex }
    provider { %w[opennode].sample }
    period_days { rand(90) }
  end
end
