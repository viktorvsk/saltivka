module Nostr
  module Nips
    module Nip1
      private

      def req_command(nostr_event)
        subscription_id, filters = nostr_event.first, nostr_event[1..]
        filters_json_string = filters.to_json # only Array of filter_sets (filters) should be stored in Redis
        pubsub_id = "#{connection_id}:#{subscription_id}"

        if !redis.sismember("client_reqs:#{connection_id}", subscription_id) && redis.scard("client_reqs:#{connection_id}") >= RELAY_CONFIG.max_subscriptions
          # NIP-11
          yield notice!("Reached maximum of #{RELAY_CONFIG.max_subscriptions} subscriptions")
        else
          redis.multi do
            redis.sadd("client_reqs:#{connection_id}", subscription_id)
            redis.hset("subscriptions", pubsub_id, filters_json_string)
          end
          sidekiq_pusher.call("NewSubscription", [connection_id, subscription_id, filters_json_string])
        end
      end

      def close_command(nostr_event)
        subscription_id = nostr_event.first
        pubsub_id = "#{connection_id}:#{subscription_id}"

        redis.multi do
          redis.del("client_reqs:#{connection_id}")
          redis.hdel("subscriptions", pubsub_id)
        end
      end

      def event_command(nostr_event)
        sidekiq_pusher.call("NewEvent", [connection_id, nostr_event.first.to_json])
      end
    end
  end
end
