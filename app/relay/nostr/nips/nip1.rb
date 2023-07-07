module Nostr
  module Nips
    module Nip1
      private

      def req_command(nostr_event, block)
        subscription_id, filters = nostr_event.first, nostr_event[1..]
        filters_json_string = filters.to_json # only Array of filter_sets (filters) should be stored in Redis
        pubsub_id = "#{connection_id}:#{subscription_id}"

        r1, r2 = redis.multi do |t|
          t.sismember("client_reqs:#{connection_id}", subscription_id)
          t.scard("client_reqs:#{connection_id}")
        end

        is_new_subscription = !ActiveRecord::Type::Boolean.new.cast(r1)
        is_limit_reached = r2 >= RELAY_CONFIG.max_subscriptions

        if is_new_subscription && is_limit_reached
          # NIP-11
          block.call notice!("error: Reached maximum of #{RELAY_CONFIG.max_subscriptions} subscriptions")
        else
          redis.multi do
            redis.sadd("client_reqs:#{connection_id}", subscription_id)
            redis.hset("subscriptions", pubsub_id, filters_json_string)
          end
          sidekiq_pusher.call("NewSubscription", [connection_id, subscription_id, filters_json_string])
        end
      end

      def close_command(nostr_event, _block)
        subscription_id = nostr_event.first
        pubsub_id = "#{connection_id}:#{subscription_id}"

        redis.multi do
          redis.del("client_reqs:#{connection_id}")
          redis.hdel("subscriptions", pubsub_id)
        end
      end

      def event_command(nostr_event, _block)
        sidekiq_pusher.call("NewEvent", [connection_id, nostr_event.first.to_json])
      end
    end
  end
end
