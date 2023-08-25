class MemStore
  class << self
    def fanout(cid:, command:, payload:, sid: "_", conn: nil)
      if conn # Reuse connection if possible
        conn.publish("events:#{cid}:#{sid}:#{command}", payload)
      else
        Sidekiq.redis { |c| c.publish("events:#{cid}:#{sid}:#{command}", payload) }
      end
    end

    def fanout_new_event_to_all_active_subscriptions(event)
      pubsubs = matching_pubsubs_for(event)
      authenticated_pubsubs = pubkeys_for(pubsubs: pubsubs)
      to_fanount = pubsubs.select { |pubsub_id| event.should_fanout?(authenticated_pubsubs[pubsub_id]) }

      Sidekiq.redis do |c|
        c.pipelined do |pipeline|
          to_fanount.each do |pubsub_id|
            cid, sid = pubsub_id.split(":")
            fanout(cid: cid, sid: sid, command: :found_event, payload: event.to_json, conn: pipeline)
          end
        end
      end
    end

    def subscribe(cid:, sid:, filters:)
      filters = [{}] if filters.blank?
      queries = filters.map { |f| SubscriptionQueryBuilder.new(f).query }

      Sidekiq.redis do |c|
        c.pipelined do |pipeline|
          pipeline.sadd("client_reqs:#{cid}", sid)
          queries.each { |query| pipeline.call("JSON.SET", "subscriptions:#{cid}:#{sid}", "$", query) }
        end
      end
    end

    def matching_pubsubs_for(event)
      query = SubscriptionMatcherQueryBuilder.new(event).query

      begin
        subscriptions = Sidekiq.redis { |c| c.call("FT.SEARCH", "subscriptions_idx", query, "NOCONTENT") }
      rescue RedisClient::CommandError => e
        Sentry.capture_exception(e)
        Rails.logger.error("[MemStore.matching_pubsubs_for][INVALID_QUERY] query=#{query} event_sha256=#{event.sha256}")
        subscriptions = []
      end

      # Removing unnecessary parts to return pubsubs
      subscriptions.shift # First argument is Redis specific return value
      subscriptions.map! { |r| r.gsub(/\Asubscriptions:/, "") } # Redis returns full keys name including "namespace" subscriptions:

      subscriptions
    end

    def pubkey_for(cid:)
      Sidekiq.redis { |c| c.hget("authentications", cid) }
    end

    def pubkeys_for(pubsubs:)
      res = {}
      return res if pubsubs.blank?
      connection_ids = pubsubs.map { |ps| ps.split(":").first }
      auth_pubsubs = Sidekiq.redis { |c| c.hmget("authentications", *connection_ids) }

      pubsubs.each_with_index do |pubsub_id, index|
        res[pubsub_id] = auth_pubsubs[index]
      end

      res
    end

    def pubkey?(cid:)
      Sidekiq.redis { |c| c.hexists("authentications", cid) }
    end

    def authenticate!(cid:, event_sha256:, pubkey:)
      Sidekiq.redis do |c|
        c.multi do |t|
          t.hset("authentications", cid, pubkey)
          t.lpush("queue:nostr.nip42", {class: "AuthorizationRequest", args: [cid, event_sha256, pubkey]}.to_json)
        end
      end
    end

    def authorize!(cid:, level:)
      Sidekiq.redis do |c|
        c.multi do |t|
          t.hset("authorizations", cid, level)
          t.lpush("authorization_result:#{cid}", level)
          t.expire("authorization_result:#{cid}", RELAY_CONFIG.authorization_timeout.to_s)
        end
      end
    end

    def connected?(cid:)
      Sidekiq.redis { |c| ActiveRecord::Type::Boolean.new.cast(c.sismember("connections", cid)) }
    end

    def update_config(cname, cvalue)
      Sidekiq.redis do |c|
        case cname
        when "unlimited_ips"
          members = cvalue.to_s.split(" ")
          if members.present?
            c.multi do |t|
              t.del("unlimited_ips")
              t.sadd("unlimited_ips", members)
            end
          else
            c.del("unlimited_ips")
          end
        else
          c.set(cname, cvalue.to_s)
        end
      end
    end

    # Those methods are used in order to validate event of kind 22242
    # for authentication of user pubkeys on the web side
    def connect(cid:)
      Sidekiq.redis { |c| c.sadd("connections", cid) }
    end

    def disconnect(cid:)
      Sidekiq.redis { |c| c.srem("connections", cid) }
    end

    def add_email_confirmation(email)
      token = SecureRandom.hex
      Sidekiq.redis do |connection|
        connection.call("set", "email_confirmations:#{token}", email, "EX", User::EMAIL_CONFIRM_EXPIRATION_SECONDS.to_s)
      end

      token
    end

    def find_email_to_confirm(token)
      Sidekiq.redis { |c| c.get("email_confirmations:#{token}") }
    end

    def confirm_email(token)
      Sidekiq.redis { |c| c.del("email_confirmations:#{token}") }
    end

    def latest_events
      Sidekiq.redis { |c| c.lrange("latest-events", "0", "99") }
    end

    def add_latest_event(event:)
      Sidekiq.redis do |c|
        c.multi do |t|
          t.lpush("latest-events", event)
          t.ltrim("latest-events", "0", "99")
        end
      end
    end
  end
end
