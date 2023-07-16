FactoryBot.define do
  factory :user do
    password { SecureRandom.hex }
    email { FFaker::Internet.email }
    confirmed_at { Time.current }
    after(:build) do |user|
      user.password_confirmation = user.password
    end

    trait :unconfirmed do
      confirmed_at { :nil }
    end
  end
end
