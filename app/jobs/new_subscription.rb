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

    pubsub_id = "#{connection_id}:#{subscription_id}"

    # TODO: this should never happen due to Nostr::NormalizedEvent
    # but let it stay here if normalization is removed one day
    filters = [{}] if filters.blank?

    union = filters.map { |filter_set| "(#{Event.by_nostr_filters(filter_set).to_sql})" }.join("\nUNION\n")

    ids = Event.find_by_sql(union).pluck(:id)

    Event.where(id: ids).find_each do |event|
      REDIS.publish("events:#{pubsub_id}", event.to_json)
    end

    REDIS.publish("events:#{pubsub_id}", "EOSE")
  end
end
