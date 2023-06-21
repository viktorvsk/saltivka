class NewEvent
  include Sidekiq::Worker
  sidekiq_options queue: "nostr"

  def perform(connection_id, event_json)
    event_params = JSON.parse(event_json)
    event_params["created_at"] = Time.at(event_params["created_at"])
    event = Event.new(event_params)

    if event.save
      # TODO: Bloom filters
      REDIS.hgetall("subscriptions").each do |pubsub_id, filters|
        matches = JSON.parse(filters).any? { |filter_set| event.matches_nostr_filter_set?(filter_set) }
        REDIS.publish("events:#{pubsub_id}:found_event", event.to_json) if matches
      end

      REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.id, true, ""].to_json)
    else
      Rails.logger.info(event.errors.to_json)

      if event.errors[:id].include?("has already been taken")
        REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.id, false, "duplicate: this event is already present in the database"].to_json)
      else
        REDIS.publish("events:#{connection_id}:_:ok", ["OK", event.id, false, "error: #{event.errors.full_messages.join(", ")}"].to_json)
      end
    end

    event
  end
end
