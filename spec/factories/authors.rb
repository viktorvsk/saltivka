FactoryBot.define do
  factory :author do
    pubkey { SecureRandom.hex(32) }
  end
end
