class Event < ApplicationRecord
  include Nostr::Nip1
  include Nostr::Nip9
  include Nostr::Nip13
  include Nostr::Nip22
  include Nostr::Nip26
  include Nostr::Nip40
  include Nostr::Nip42

  def should_fanout?(subscriber_pubkey)
    return true unless RELAY_CONFIG.enforce_kind_4_authentication
    return true unless kind === 4

    event_p_tag = tags.find { |t| t.first == "p" }

    if event_p_tag.blank?
      Sentry.capture_message("[NewEvent][InvalidKind4Event] event=#{to_json}", level: :warning)
      return false
    end

    receiver_pubkey = event_p_tag.second

    # TODO: consider delegation
    subscriber_pubkey.in?([receiver_pubkey, pubkey])
  end
end
