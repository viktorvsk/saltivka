class MemStore
  class << self
    def fanout(cid:, command:, payload:, sid: "_")
      Sidekiq.redis { |c| c.publish("events:#{cid}:#{sid}:#{command}", payload) }
    end

    # TODO: This should be a LUA script
    def fanout_new_event_to_all_active_subscriptions(event)
      subscriptions.each do |pubsub_id, filters|
        matches = JSON.parse(filters).any? { |filter_set| event.matches_nostr_filter_set?(filter_set) }
        next unless matches
        subscriber_cid, subscriber_sid = pubsub_id.split(":")
        subscriber_pubkey = pubkey_for(cid: subscriber_cid)

        fanout(cid: subscriber_cid, sid: subscriber_sid, command: :found_event, payload: event.to_json) if should_fanout?(event, subscriber_pubkey)
      end
    end

    def should_fanout?(event, subscriber_pubkey)
      return true unless RELAY_CONFIG.enforce_kind_4_authentication
      return true unless event.kind === 4

      event_p_tag = event.tags.find { |t| t.first == "p" }

      if event_p_tag.blank?
        Sentry.capture_message("[NewEvent][InvalidKind4Event] event=#{event.to_json}", level: :warning)
        return false
      end

      receiver_pubkey = event_p_tag.second

      # TODO: consider delegation
      subscriber_pubkey.in?([receiver_pubkey, event.pubkey])
    end
    ### ENDTODO

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
  end
end
