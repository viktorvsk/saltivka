module Nostr
  module Nips
    module Nip45
      private

      def count_command(nostr_event, block)
        subscription_id, filters = nostr_event.first, nostr_event[1..]
        filters_json_string = filters.to_json # only Array of filter_sets (filters) should be stored in Redis

        redis.lpush("queue:nostr.nip45", {class: "CountRequest", args: [connection_id, subscription_id, filters_json_string]}.to_json)
      end
    end
  end
end
