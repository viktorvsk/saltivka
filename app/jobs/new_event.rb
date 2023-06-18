class NewEvent
  include Sidekiq::Worker
  sidekiq_options queue: "nostr"

  def perform(event)
    event = Event.create(JSON.parse(event))
    REDIS.hgetall("subscriptions").each do |connection_with_subscription_id, filters|
      matches = JSON.parse(filters).any? { |filter_set| event.matches_nostr_filter_set?(filter_set) }
      REDIS.publish("events:#{connection_with_subscription_id}", event) if matches
    end
  end
end
