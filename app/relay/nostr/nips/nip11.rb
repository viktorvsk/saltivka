module Nostr
  module Nips
    class Nip11
      def self.call
        # TODO: retention, payment_url, fees, icon
        {
          name: RELAY_CONFIG.relay_name,
          description: RELAY_CONFIG.description,
          pubkey: RELAY_CONFIG.pubkey,
          contact: RELAY_CONFIG.contact,
          supported_nips: RELAY_CONFIG.supported_nips,
          software: RELAY_CONFIG.software,
          version: RELAY_CONFIG.version,
          limitation: {
            max_message_length: RELAY_CONFIG.max_message_length,
            max_subscriptions: RELAY_CONFIG.max_subscriptions,
            max_filters: RELAY_CONFIG.max_filters,
            max_limit: RELAY_CONFIG.max_limit,
            max_subid_length: 64, # NIP-01 defines it as max of 64
            min_prefix: RELAY_CONFIG.min_prefix,
            max_event_tags: RELAY_CONFIG.max_event_tags,
            max_content_length: RELAY_CONFIG.max_content_length,
            min_pow_difficulty: RELAY_CONFIG.min_pow,
            auth_required: RELAY_CONFIG.forced_min_auth_level > 0,
            payment_required: false # TODO
          },
          relay_countries: RELAY_CONFIG.relay_countries,
          language_tags: RELAY_CONFIG.language_tags,
          tags: RELAY_CONFIG.tags,
          posting_policy: RELAY_CONFIG.posting_policy_url
        }
      end
    end
  end
end
