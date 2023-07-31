FactoryBot.define do
  factory :relay_mirror do
    url { "wss://relay.url#{rand}.com" }
    mirror_type { %w[past future].sample }
    oldest { 0 }
    newest { Time.now.to_i }
  end
end
