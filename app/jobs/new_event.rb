class NewEvent
  include Sidekiq::Worker
  sidekiq_options queue: "nostr"

  def perform(connection_id, event_json)
    event_params = JSON.parse(event_json)
    event_params["created_at"] = Time.at(event_params["created_at"])
    event_params["digest_and_sig"] = [event_params.delete("id"), event_params.delete("sig")]

    event = Event.new(event_params)

    if (event.kinda?(:ephemeral) && event.valid?) || event.save
      # TODO: Bloom filters
      REDIS.hgetall("subscriptions").each do |pubsub_id, filters|
        matches = JSON.parse(filters).any? { |filter_set| event.matches_nostr_filter_set?(filter_set) }
        REDIS.publish("events:#{pubsub_id}:found_event", event.to_json) if matches
      end

      REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.sha256, true, ""].to_json) unless event.kinda?(:ephemeral) # NIP-16
    else
      Rails.logger.info(event.errors.to_json)

      if event.errors[:"event_digest.sha256"].include?("has already been taken") || event.errors[:"event_digest.sig.schnorr"].include?("has already been taken")
        REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.sha256, false, "duplicate: this event is already present in the database"].to_json)
      elsif event.errors[:"event_digest.sha256"].any? { |error_text| error_text.to_s =~ /PoW difficulty must be at least/ }
        REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.sha256, false, "pow: min difficulty must be #{RELAY_CONFIG.min_pow}, got #{event.pow_difficulty}"].to_json)
      else
        REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.sha256, false, "error: #{event.errors.full_messages.join(", ")}"].to_json)
      end
    end

    event
  end
end
