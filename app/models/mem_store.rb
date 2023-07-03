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

    def auth!(cid:, pubkey:)
      Sidekiq.redis { |c| c.hset("authentications", cid, pubkey) }
    end

    def subscriptions
      Sidekiq.redis { |c| c.hgetall("subscriptions") }
    end

    def connected?(cid:)
      Sidekiq.redis { |c| ActiveRecord::Type::Boolean.new.cast(c.sismember("connections", cid)) }
    end
  end
end
