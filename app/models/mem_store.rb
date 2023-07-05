class MemStore
  class << self
    def fanout(cid:, command:, payload:, sid: "_")
      Sidekiq.redis { |c| c.publish("events:#{cid}:#{sid}:#{command}", payload) }
    end

    def pubkey_for(cid:)
      Sidekiq.redis { |c| c.hget("authentications", cid) }
    end

    def pubkey?(cid:)
      Sidekiq.redis { |c| c.hexists("authentications", cid) }
    end

    def authenticate!(cid:, event_sha256:, pubkey:)
      Sidekiq.redis do |c|
        c.multi do
          c.hset("authentications", cid, pubkey)
          c.lpush("queue:nostr", {class: "AuthorizationRequest", args: [cid, event_sha256, pubkey]}.to_json)
        end
      end
    end

    def authorize!(cid:, level:)
      Sidekiq.redis do |c|
        c.multi do
          c.hset("authorizations", cid, level)
          c.lpush("authorization_result:#{cid}", level)
          c.expire("authorization_result:#{cid}", RELAY_CONFIG.authorization_timeout.to_s)
        end
      end
    end

    def subscriptions
      Sidekiq.redis { |c| c.hgetall("subscriptions") }
    end

    def connected?(cid:)
      Sidekiq.redis { |c| ActiveRecord::Type::Boolean.new.cast(c.sismember("connections", cid)) }
    end
  end
end
