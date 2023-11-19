module Nostr
  module Nips
    module Nip65
      def self.call(command, nostr_event)
        case command
        when "EVENT"
          event = nostr_event.last
          true if event["kind"].to_i.in?(RELAY_CONFIG.kinds_exempt_of_auth)
        when "REQ", "COUNT"
          filters = nostr_event[1..]
          true if filters&.all? { |f| f["kinds"]&.all? { |k| k.to_i.in?(RELAY_CONFIG.kinds_exempt_of_auth) } }
        else
          false
        end
      end
    end
  end
end
