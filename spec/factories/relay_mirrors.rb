FactoryBot.define do
  factory :relay_mirror do
    url { "wss://relay.url#{rand}.com" }
  end
end
