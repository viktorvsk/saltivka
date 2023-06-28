require_relative "../test_helper"

FactoryBot.define do
  factory :event do
    kind { rand(0..1000) }
    content { "" }
    created_at { Time.now }

    # TODO: control whos fake credentials to use in order to control keys assigned
    # TODO: generate ID and SIG for alice/bob/etc trait events

    trait :delegated_event do
      tags { [["delegation", NIP_26_TAG[:pk], NIP_26_TAG[:conditions], NIP_26_TAG[:sig]]] }
    end

    after(:build) do |event|
      if event.pubkey.blank?
        _random_fake_signer_name, credentials = FAKE_CREDENTIALS.to_a.sample
        event.pubkey = credentials[:pk]
        event_digest = Digest::SHA256.hexdigest(JSON.dump(event.to_nostr_serialized))
        sig = Schnorr.sign([event_digest].pack("H*"), [credentials[:sk]].pack("H*")).encode.unpack1("H*")

        event.digest_and_sig = [event_digest, sig]
      elsif event.pubkey.in?(FAKE_CREDENTIALS.values.map(&:values).flatten)
        sk = FAKE_CREDENTIALS.find { |user, credentials| credentials[:pk] == event.pubkey }.last[:sk]
        event_digest = Digest::SHA256.hexdigest(JSON.dump(event.to_nostr_serialized))
        sig = Schnorr.sign([event_digest].pack("H*"), [sk].pack("H*")).encode.unpack1("H*")

        event.digest_and_sig = [event_digest, sig]
      end
    end
  end
end
