class NewSubscription
  include Sidekiq::Worker
  sidekiq_options queue: "nostr"

  def perform(connection_id, subscription_id, filters)
    filters = begin
      JSON.parse(filters)
    rescue
      return
    end
    return if connection_id.blank? || subscription_id.blank?

    filters = [{}] if filters.blank? # this shouldn't happen but still
    filters = [filters] unless filters.is_a?(Array) # this shouldn't happen but still

    pubsub_id = "#{connection_id}:#{subscription_id}"
    subscriber_pubkey = REDIS.hget("authentications", connection_id)

    union = filters.map { |filter_set| "(#{Event.by_nostr_filters(filter_set, subscriber_pubkey).to_sql})" }.join("\nUNION\n")

    ids = Event.find_by_sql(union).pluck(:id)

    Event.where(id: ids).find_each do |event|
      REDIS.publish("events:#{pubsub_id}:found_event", event.to_json)
    end

    REDIS.publish("events:#{pubsub_id}:found_end", "EOSE")
  end
end
