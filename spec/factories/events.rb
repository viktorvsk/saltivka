FactoryBot.define do
  factory :event do
    kind { rand(0..1000) }
    content { "" }
    created_at { Time.now }

    trait :delegated_event do
      tags { [["delegation", NIP_26_TAG[:pk], NIP_26_TAG[:conditions], NIP_26_TAG[:sig]]] }
    end

    after(:build) do |event|
      if event.pubkey.blank?
        _random_fake_signer_name, credentials = FAKE_CREDENTIALS.to_a.sample
        event.pubkey = credentials[:pk]
        sha256 = Digest::SHA256.hexdigest(JSON.dump(event.to_nostr_serialized))
        sig = Schnorr.sign([sha256].pack("H*"), [credentials[:sk]].pack("H*")).encode.unpack1("H*")

        event.sha256 = sha256
        event.sig = sig
      elsif event.pubkey.in?(FAKE_CREDENTIALS.values.map(&:values).flatten)
        sk = FAKE_CREDENTIALS.find { |user, credentials| credentials[:pk] == event.pubkey }.last[:sk]
        sha256 = Digest::SHA256.hexdigest(JSON.dump(event.to_nostr_serialized))
        sig = Schnorr.sign([sha256].pack("H*"), [sk].pack("H*")).encode.unpack1("H*")

        event.sha256 = sha256
        event.sig = sig
      end
    end
  end
end
