class NewEvent
  include Sidekiq::Worker
  sidekiq_options queue: "nostr"

  def perform(connection_id, event_json)
    event_params = JSON.parse(event_json)
    event_params["created_at"] = Time.at(event_params["created_at"])
    event_params["sha256"] = event_params.delete("id")

    event = Event.new(event_params)
    should_fanout_without_save = event.kinda?(:ephemeral) && event.valid?

    if should_fanout_without_save || event.save

      if event.kinda?(:private)
        if event.kind === 22242 # NIP-42
          if RELAY_CONFIG.restrict_change_auth_pubkey && REDIS.hexists("authentications", connection_id)
            REDIS.publish("events:#{connection_id}:_:notice", "This connection is already authenticated. To authenticate another pubkey please open new connection")
          else
            REDIS.hset("authentications", connection_id, event.pubkey)
          end
        end
      else
        # TODO: Bloom filters
        REDIS.hgetall("subscriptions").each do |pubsub_id, filters|
          matches = JSON.parse(filters).any? { |filter_set| event.matches_nostr_filter_set?(filter_set) }
          next unless matches
          if event.kind === 4
            event_p_tag = event.tags.find { |t| t.first == "p" }
            next unless event_p_tag.present? # TODO: process invalid kind 4 event
            subscriber_connection_id = pubsub_id.split(":").first
            subscriber_pubkey = REDIS.hget("authentications", subscriber_connection_id)
            # We don't have to send this event to author because only subscriptions
            # with matching filters should receive it
            # We also don't have to do anything regarding delegation because
            # delegation is only about publishing events and not receiving
            next if event_p_tag.second != subscriber_pubkey
          end

          REDIS.publish("events:#{pubsub_id}:found_event", event.to_json)
        end

        REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.sha256, true, ""].to_json) unless event.kinda?(:ephemeral) # NIP-16/NIP-20
      end
    elsif event.errors[:sha256].include?("has already been taken") || event.errors[:sig].include?("has already been taken")
      REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.sha256, false, "duplicate: this event is already present in the database"].to_json)
    elsif event.errors[:sha256].any? { |error_text| error_text.to_s =~ /PoW difficulty must be at least/ }
      REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.sha256, false, "pow: min difficulty must be #{RELAY_CONFIG.min_pow}, got #{event.pow_difficulty}"].to_json)
    elsif event.errors[:"author.pubkey"].include?("has already been taken") || event.author.errors[:pubkey].include?("has already been taken")
      NewEvent.perform_async(connection_id, event_json)
      return event
    else
      REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.sha256, false, "error: #{event.errors.full_messages.join(", ")}"].to_json) # TODO: errors presenter
    end

    event
  rescue ActiveRecord::RecordNotUnique => e
    REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.sha256, false, "duplicate: this event is already present in the database"].to_json)
  end
end
