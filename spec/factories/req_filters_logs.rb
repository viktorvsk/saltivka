FactoryBot.define do
  factory :req_filters_log do
    filters { [{kinds: [rand.to_i]}] }
  end
end
