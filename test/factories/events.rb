require_relative "../test_helper"

FactoryBot.define do
  factory :event do
    kind { rand(0..1000) }
    content { "" }
    created_at { Time.now }

    after(:build) do |event|
      if event.pubkey.blank?
        _random_fake_signer_name, credentials = FAKE_CREDENTIALS.to_a.sample

        event.pubkey = credentials[:pk]
        event.id = Digest::SHA256.hexdigest(JSON.dump(event.to_nostr_serialized))
        event.sig = Schnorr.sign([event.id].pack("H*"), [credentials[:sk]].pack("H*")).encode.unpack1("H*")
      end
    end
  end
end
