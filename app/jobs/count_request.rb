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

    union = filters.map { |filter_set| "(#{Event.by_nostr_filters(filter_set, subscriber_pubkey, true).to_sql})" }.join("\nUNION\n")

    unless RELAY_CONFIG.count_cost_threshold.zero?
      explain = ActiveRecord::Base.connection.execute("EXPLAIN #{union}").first.to_s
      rows = explain[/rows=(\d+)/, 1].to_i
      cost = explain[/cost=\d+\.\d+\.\.(\d+)/, 1].to_i
      should_count_approximate = RELAY_CONFIG.count_cost_threshold.positive? && cost > RELAY_CONFIG.count_cost_threshold
    end

    count = should_count_approximate ? rows : Event.includes(:author).from("(#{union}) AS t").count

    payload = {count: count.to_i}

    payload[:approximate] = should_count_approximate if RELAY_CONFIG.count_cost_threshold.positive?

    MemStore.fanout(cid: connection_id, sid: subscription_id, command: :count, payload: payload.to_json)
    count
  end
end
