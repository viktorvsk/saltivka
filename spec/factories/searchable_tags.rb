FactoryBot.define do
  factory :searchable_tag do
    event
    name { ("a".."z").to_a.sample }
    value { SecureRandom.hex }
  end
end
