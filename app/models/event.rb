class Event < ApplicationRecord
  KNOWN_KINDS_TYPES = %w[set_metadata text_note recommend_server delete_event protocol_reserved replaceable ephemeral]
  include Nostr::Nip1
  include Nostr::Nip1Nip2Nip16
  include Nostr::Nip9
  include Nostr::Nip13
  include Nostr::Nip22

  # NIP-01 NIP-02 NIP-16 NIP-33
  def kinda?(event_type)
    raise "Unknown event kind type" unless event_type.to_s.downcase.in?(KNOWN_KINDS_TYPES)

    kind_types = case kind
    when 0
      %w[set_metadata protocol_reserved replaceable]
    when 1
      %w[text_note protocol_reserved]
    when 2
      %w[recommend_server protocol_reserved]
    when 3
      %w[contact_list protocol_reserved replaceable]
    when 5
      %w[delete_event protocol_reserved]
    when 0...1000
      %w[protocol_reserved]
    when 1000...10000
      %w[regular]
    when 10000...20000
      %w[replaceable]
    when 20000...30000
      %w[ephemeral]
    when 30000...40000
      %w[parameterized replaceable]
    else
      %w[unknown]
    end

    event_type.to_s.in?(kind_types)
  end
end
