module Nostr
  module Nips
    module Nip1
      private

      def req_command(nostr_event, block)
        subscription_id, filters = nostr_event.first, nostr_event[1..]
        filters_json_string = filters.to_json # only Array of filter_sets (filters) should be stored in Redis

        r1 = r2 = nil

        MemStore.with_redis do |redis|
          r1, r2 = redis.multi do |t|
            t.sismember("client_reqs:#{connection_id}", subscription_id)
            t.scard("client_reqs:#{connection_id}")
          end
        end

        is_new_subscription = !ActiveRecord::Type::Boolean.new.cast(r1)
        is_limit_reached = r2 >= RELAY_CONFIG.max_subscriptions

        if is_new_subscription && is_limit_reached
          # NIP-11
          block.call notice!("error: Reached maximum of #{RELAY_CONFIG.max_subscriptions} subscriptions")
        else
          MemStore.with_sidekiq { |redis| redis.lpush("queue:nostr.nip01.req", {class: "NewSubscription", args: [connection_id, subscription_id, filters_json_string]}.to_json) }
        end
      end

      def close_command(nostr_event, _block)
        subscription_id = nostr_event.first

        MemStore.with_redis do |redis|
          redis.pipelined do |pipeline|
            pipeline.srem("client_reqs:#{connection_id}", subscription_id)
            pipeline.del("subscriptions:#{connection_id}:#{subscription_id}")
          end
        end
      end

      def event_command(nostr_event, block)
        MemStore.with_sidekiq { |redis| redis.lpush("queue:nostr.nip01.event", {class: "NewEvent", args: [connection_id, nostr_event.first.to_json]}.to_json) }
      end
    end
  end
end
