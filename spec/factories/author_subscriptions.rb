FactoryBot.define do
  factory :author_subscription do
    author

    trait :active do
      expires_at { 10.days.from_now }
    end
  end
end
