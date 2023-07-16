FactoryBot.define do
  factory :delete_event do
    sha256 { SecureRandom.hex(32) }
    author
  end
end
