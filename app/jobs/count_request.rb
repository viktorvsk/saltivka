class CountRequest
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

    count = Event.from("(#{union}) AS t").count

    REDIS.publish("events:#{pubsub_id}:count", count.to_s)
    count
  end
end
