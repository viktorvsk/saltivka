Nostr::Relay = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env) # standard websocket connection object

    redis = Redis.new(url: ENV["REDIS_URL"])

    controller = Nostr::RelayController.new(redis: REDIS)
    connection_id = controller.connection_id

    redis_thread = Thread.new do
      redis.psubscribe("events:#{connection_id}:*") do |on|
        on.pmessage do |pattern, channel, event|
          response = Nostr::RelayProcessor.call(channel, event)
          ws.send(response)
        end
      end
    end

    # Client side events logic
    ws.on :message do |event|
      controller.perform(event.data) do |notice|
        ws.send(notice)
      end
    end

    ws.on :close do |event|
      Rails.logger.info("[T E R M I N A T I N G] connection_id=#{connection_id}")
      redis.unsubscribe if redis.subscribed?
      redis_thread.exit
      redis.multi do
        connection_subscriptions = redis.smembers("client_reqs:#{connection_id}")
        redis.del("client_reqs:#{connection_id}")
        redis.hdel("subscriptions", connection_subscriptions.map { |req| "#{connection_id}:#{req}" }) if connection_subscriptions.present?
      end
      redis_thread = nil
      ws = nil
    end

    ws.rack_response # async
  else
    [200, {"Content-Type" => "text/plain"}, ["Hello"]]
  end
end
