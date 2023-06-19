class NewSubscription
  include Sidekiq::Worker
  sidekiq_options queue: "nostr"

  def perform(connection_id, subscription_id, filters)
    filters = JSON.parse(filters)
    pubsub_id = "#{connection_id}:#{subscription_id}"

    union = filters.map { |filter_set| Event.by_nostr_filters(filter_set).to_sql }.join("\nUNION\n")

    ids = Event.find_by_sql(union).pluck(:id)

    Event.where(id: ids).find_each do |event|
      REDIS.publish("events:#{pubsub_id}", event.to_json)
    end

    REDIS.publish("events:#{pubsub_id}", "EOSE")
  end
end
