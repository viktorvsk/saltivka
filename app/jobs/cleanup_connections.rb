class CleanupConnections
  include Sidekiq::Worker
  sidekiq_options queue: "default"

  def perform
    Sidekiq.redis do |redis|
      subscriptions_connections = redis.keys("subscriptions:*").map { |sub| sub.split(":")[1] }
      connections = redis.smembers("connections")
      all_connections = [connections, subscriptions_connections].flatten.uniq
      inactive_connections = all_connections.select { |cid| redis.publish("events:#{cid}:_:ping", "0").zero? }
      inactive_connections.each { |cid| Nostr::RelayController.new(connection_id: cid).terminate(event: nil, redis: c) }
    end
  end
end