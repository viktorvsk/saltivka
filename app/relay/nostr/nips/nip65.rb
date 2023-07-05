module Nostr
  module Nips
    module Nip65
      def self.call(command, nostr_event)
        if command === "EVENT"
          event = nostr_event.last
          return true if event["kind"].to_i.in?(RELAY_CONFIG.kinds_exempt_of_auth)
        elsif command === "REQ"
          filters = nostr_event[1..]
          return true if filters&.all? { |f| f["kinds"]&.all? { |k| k.to_i.in?(RELAY_CONFIG.kinds_exempt_of_auth) } }
        end

        false
      end
    end
  end
end
