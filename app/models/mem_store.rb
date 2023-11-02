class MemStore
  class << self
    REDIS_CONNECTIONS_POOL = ConnectionPool.new(size: ENV.fetch("RAILS_MAX_THREADS", 5), timeout: ENV.fetch("REDIS_POOL_TIMEOUT", 5)) { Redis.new(url: ENV["REDIS_URL"], driver: :hiredis) }

    def fanout(cid:, command:, payload:, sid: "_", conn: nil)
      if conn # Reuse connection if possible
        conn.publish("events:#{cid}:#{sid}:#{command}", payload)
      else
        with_redis { |redis| redis.publish("events:#{cid}:#{sid}:#{command}", payload) }
      end
    end

    def fanout_new_event_to_all_active_subscriptions(event)
      pubsubs = matching_pubsubs_for(event)
      authenticated_pubsubs = pubkeys_for(pubsubs: pubsubs)
      to_fanount = pubsubs.select { |pubsub_id| event.should_fanout?(authenticated_pubsubs[pubsub_id]) }

      with_redis do |redis|
        redis.pipelined do |pipeline|
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

      with_redis do |redis|
        redis.pipelined do |pipeline|
          pipeline.sadd("client_reqs:#{cid}", sid)
          queries.each { |query| pipeline.call("JSON.SET", "subscriptions:#{cid}:#{sid}", "$", query) }
        end
      end
    end

    def matching_pubsubs_for(event)
      query = SubscriptionMatcherQueryBuilder.new(event).query

      begin
        subscriptions = with_redis { |redis| redis.call("FT.SEARCH", "subscriptions_idx", query, "NOCONTENT") }
      rescue RedisClient::CommandError => e
        Sentry.capture_exception(e)
        Rails.logger.error("[MemStore.matching_pubsubs_for][INVALID_QUERY] query=#{query} event_sha256=#{event.sha256}")
        subscriptions = []
      end

      # Removing unnecessary parts to return pubsubs
      subscriptions.shift # First argument is Redis specific return value
      subscriptions.map! { |r| r.gsub(/\Asubscriptions:/, "") } # Redis returns full keys name including "namespace" subscriptions:

      # TODO: workaround to the fact that we want NIP-50 search to also produce
      # events that are coming after EOSE but RedisSearch doesn't provide equivalent
      # functionality we could use in our case. Thats why here we retrieve all
      # the subscriptions that have #search filter
      subscriptions_with_search_filter = with_redis { |redis| redis.call("FT.SEARCH", "subscriptions_idx", "-@search:#{SubscriptionQueryBuilder::REDIS_SEARCH_TAG_ANY_VALUE}") }

      subscriptions_with_search_filter.shift # First argument is Redis specific return value
      subscriptions_with_search_filter = Hash[*subscriptions_with_search_filter] # convert to hash
      subscriptions_with_search_filter.transform_keys! { |k| k.gsub(/\Asubscriptions:/, "") } # Redis returns full keys name including "namespace" subscriptions:
      subscriptions_with_search_filter.transform_values! { |v| JSON.parse(v.last)["search"] } # extracting search query per subscription
      subscriptions_with_search_filter.select! { |k, v| k.in?(subscriptions) } # We receive all subscriptions with #search filter here so we remove those which don't match other filters i.e. #kind

      subscriptions.reject! do |pubsub_id|
        filters_by_search = pubsub_id.in?(subscriptions_with_search_filter.keys)
        searchable_event = event.kind.in?(RELAY_CONFIG.content_searchable_kinds)
        search_query = subscriptions_with_search_filter[pubsub_id]

        # Do not fanout events to subscriptions which have search kind in case
        # if event is not of a searchable kind or if event content does not match
        # subscription query
        filters_by_search && (!searchable_event || !event.matches_full_text_search?(search_query))
      end

      subscriptions
    end

    def pubkey_for(cid:)
      with_redis { |redis| redis.hget("authentications", cid) }
    end

    def pubkeys_for(pubsubs:)
      res = {}
      return res if pubsubs.blank?
      connection_ids = pubsubs.map { |ps| ps.split(":").first }
      auth_pubsubs = with_redis { |redis| redis.hmget("authentications", *connection_ids) }

      pubsubs.each_with_index do |pubsub_id, index|
        res[pubsub_id] = auth_pubsubs[index]
      end

      res
    end

    def pubkey?(cid:)
      with_redis { |redis| redis.hexists("authentications", cid) }
    end

    def authenticate!(cid:, event_sha256:, pubkey:)
      with_sidekiq { |redis| redis.lpush("queue:nostr.nip42", {class: "AuthorizationRequest", args: [cid, event_sha256, pubkey]}.to_json) }
      with_redis { |redis| redis.hset("authentications", cid, pubkey) }
    end

    def authorize!(cid:, level:)
      with_redis do |redis|
        redis.multi do |t|
          t.hset("authorizations", cid, level)
          t.lpush("authorization_result:#{cid}", level)
          t.expire("authorization_result:#{cid}", RELAY_CONFIG.authorization_timeout.to_s)
        end
      end
    end

    def connected?(cid:)
      with_redis { |redis| ActiveRecord::Type::Boolean.new.cast(redis.sismember("connections", cid)) }
    end

    def update_config(cname, cvalue)
      with_redis do |redis|
        case cname
        when "unlimited_ips"
          members = cvalue.to_s.split(" ")
          if members.present?
            redis.multi do |t|
              t.del("unlimited_ips")
              t.sadd("unlimited_ips", members)
            end
          else
            redis.del("unlimited_ips")
          end
        else
          redis.set(cname, cvalue.to_s)
        end
      end
    end

    # Those methods are used in order to validate event of kind 22242
    # for authentication of user pubkeys on the web side
    def connect(cid:)
      with_redis { |redis| redis.sadd("connections", cid) }
    end

    def disconnect(cid:)
      with_redis { |redis| redis.srem("connections", cid) }
    end

    def add_email_confirmation(email)
      token = SecureRandom.hex
      with_redis do |redis|
        redis.call("set", "email_confirmations:#{token}", email, "EX", User::EMAIL_CONFIRM_EXPIRATION_SECONDS.to_s)
      end

      token
    end

    def find_email_to_confirm(token)
      with_redis { |redis| redis.get("email_confirmations:#{token}") }
    end

    def confirm_email(token)
      with_redis { |redis| redis.del("email_confirmations:#{token}") }
    end

    def latest_events
      with_redis { |redis| redis.lrange("latest-events", "0", "99") }
    end

    def add_latest_event(event:)
      with_redis do |redis|
        redis.multi do |t|
          t.lpush("latest-events", event)
          t.ltrim("latest-events", "0", "99")
        end
      end
    end

    def with_redis
      REDIS_CONNECTIONS_POOL.with do |connection|
        yield connection if block_given?
      end
    end

    def with_sidekiq
      Sidekiq.redis do |connection|
        yield connection if block_given?
      end
    end
  end
end
