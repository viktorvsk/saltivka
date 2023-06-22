module Nostr
  module Nips
    module Nip45
      private

      def count_command(nostr_event)
        subscription_id, filters = nostr_event.first, nostr_event[1..]
        filters_json_string = filters.to_json # only Array of filter_sets (filters) should be stored in Redis

        sidekiq_pusher.call("CountRequest", [connection_id, subscription_id, filters_json_string])
      end
    end
  end
end
