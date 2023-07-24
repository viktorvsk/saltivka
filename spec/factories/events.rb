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

        ctx = Secp256k1::Context.new
        key_pair = ctx.key_pair_from_private_key([credentials[:sk]].pack("H*"))
        sig = ctx.sign_schnorr(key_pair, [sha256].pack("H*")).serialized.unpack1("H*")

        event.sha256 = sha256
        event.sig = sig
      elsif event.pubkey.in?(FAKE_CREDENTIALS.values.map(&:values).flatten)
        sk = FAKE_CREDENTIALS.find { |user, credentials| credentials[:pk] == event.pubkey }.last[:sk]
        sha256 = Digest::SHA256.hexdigest(JSON.dump(event.to_nostr_serialized))

        ctx = Secp256k1::Context.new
        key_pair = ctx.key_pair_from_private_key([sk].pack("H*"))
        sig = ctx.sign_schnorr(key_pair, [sha256].pack("H*")).serialized.unpack1("H*")

        event.sha256 = sha256
        event.sig = sig
      end
    end
  end
end
