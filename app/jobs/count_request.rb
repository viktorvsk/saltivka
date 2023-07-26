class CountRequest
  include Sidekiq::Worker
  sidekiq_options queue: "nostr.nip45"

  def perform(connection_id, subscription_id, filters)
    filters = begin
      JSON.parse(filters)
    rescue => e
      Sentry.capture_exception(e)
      return
    end
    return if connection_id.blank? || subscription_id.blank?

    filters = [{}] if filters.blank? # this shouldn't happen but still
    filters = [filters] unless filters.is_a?(Array) # this shouldn't happen but still

    subscriber_pubkey = MemStore.pubkey_for(cid: connection_id)

    union = filters.map { |filter_set| "(#{Event.by_nostr_filters(filter_set, subscriber_pubkey).to_sql})" }.join("\nUNION\n")

    count = Event.from("(#{union}) AS t").count

    MemStore.fanout(cid: connection_id, sid: subscription_id, command: :count, payload: count.to_s)
    count
  end
end
