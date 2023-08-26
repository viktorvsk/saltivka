class ReprocessSeenEvents
  include Sidekiq::Worker
  sidekiq_options queue: "default"

  def perform
    events_order_of_magnitude = Event.count.to_s.length
    seen_events_order_of_magnitude = MemStore.with_redis { |redis| redis.call("BF.CARD", "seen-events").to_s.length }

    # We only want to run this in case if Redis state was reset
    return if events_order_of_magnitude == seen_events_order_of_magnitude

    Event.select("id, LOWER(sha256) AS sha256").find_in_batches do |events|
      MemStore.with_redis do |redis|
        redis.pipelined do |pipeline|
          events.map(&:sha256).each { |event_sha256| pipeline.call("BF.ADD", "seen-events", event_sha256) }
        end
      end
    end
  end
end
