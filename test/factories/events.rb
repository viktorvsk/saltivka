require_relative "../test_helper"

FactoryBot.define do
  factory :event do
    kind { rand(0..1000) }
    content { "" }
    created_at { Time.now }

    after(:build) do |event|
      unless event&.author&.pubkey&.present?
        _random_fake_signer_name, credentials = FAKE_CREDENTIALS.to_a.sample
        event.pubkey = credentials[:pk]
        event_digest = Digest::SHA256.hexdigest(JSON.dump(event.to_nostr_serialized))
        sig = Schnorr.sign([event_digest].pack("H*"), [credentials[:sk]].pack("H*")).encode.unpack1("H*")

        event.digest_and_sig = [event_digest, sig]

      end
    end
  end
end
