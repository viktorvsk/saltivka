class NewEvent
  include Sidekiq::Worker
  sidekiq_options queue: "nostr"

  def perform(connection_id, event_json)
    event_params = JSON.parse(event_json)
    event_params["created_at"] = Time.at(event_params["created_at"])
    event_params["digest_and_sig"] = [event_params.delete("id"), event_params.delete("sig")]

    event = Event.new(event_params)
    should_fanout_without_save = event.kinda?(:ephemeral) && event.valid?

    if should_fanout_without_save || event.save

      if event.kinda?(:private)
        if event.kind === 22242 # NIP-42
          REDIS.hset("authentications", connection_id, event.pubkey)
        end
      else
        # TODO: Bloom filters
        REDIS.hgetall("subscriptions").each do |pubsub_id, filters|
          matches = JSON.parse(filters).any? { |filter_set| event.matches_nostr_filter_set?(filter_set) }
          next unless matches
          if event.kind === 4
            subscriber_connection_id = pubsub_id.split(":").first
            subscriber_pubkey = REDIS.hget("authentications", subscriber_connection_id)
            event_p_tag = event.tags.find { |t| t.first == "p" }
            # We don't have to send this event to author because only subscriptions
            # with matching filters should receive it
            # We also don't have to do anything regarding delegation because
            # delegation is only about publishing events and not receiving
            if event_p_tag.present?
              receiver_pubkey = event_p_tag.second
              if receiver_pubkey === subscriber_pubkey
                REDIS.publish("events:#{pubsub_id}:found_event", event.to_json)
              else
                next
              end
            else
              # TODO: process invalid kind 4 event
              next
            end
          else
            REDIS.publish("events:#{pubsub_id}:found_event", event.to_json)
          end
        end

        REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.sha256, true, ""].to_json) unless event.kinda?(:ephemeral) # NIP-16
      end
    else
      Rails.logger.info(event.errors.to_json)

      if event.errors[:"event_digest.sha256"].include?("has already been taken") || event.errors[:"event_digest.sig.schnorr"].include?("has already been taken")
        REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.sha256, false, "duplicate: this event is already present in the database"].to_json)
      elsif event.errors[:"event_digest.sha256"].any? { |error_text| error_text.to_s =~ /PoW difficulty must be at least/ }
        REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.sha256, false, "pow: min difficulty must be #{RELAY_CONFIG.min_pow}, got #{event.pow_difficulty}"].to_json)
      else
        REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.sha256, false, "error: #{event.errors.full_messages.join(", ")}"].to_json) # TODO: errors presenter
      end
    end

    event
  end
end
