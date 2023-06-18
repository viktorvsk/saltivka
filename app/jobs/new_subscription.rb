class NewSubscription
  include Sidekiq::Worker
  sidekiq_options queue: "nostr"

  def perform(connection_id, subscription_id, filters)
    filters = JSON.parse(filters)

    union = filters.map { |filter_set| Event.by_nostr_filters(filter_set).to_sql }.join("\nUNION\n")

    ids = Event.find_by_sql(union).pluck(:id)

    Event.where(id: ids).find_each do |event|
      REDIS.publish("events:#{connection_id}:#{subscription_id}", event.to_json)
    end

    REDIS.publish("events:#{connection_id}:#{subscription_id}", "EOSE")
  end
end
