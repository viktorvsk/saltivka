Nostr::Relay = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env) # standard websocket connection object

    redis_subscriber = Redis.new(url: ENV["REDIS_URL"])

    controller = Nostr::RelayController.new(redis: REDIS)
    relay_processor = Nostr::RelayProcessor.new(ws: ws)
    connection_id = controller.connection_id
    REDIS.sadd("connections", connection_id)

    Nostr::AuthenticationFlow.call(ws.url, connection_id) { |event| ws.send(event) }

    redis_thread = Thread.new do
      redis_subscriber.psubscribe("events:#{connection_id}:*") do |on|
        on.pmessage do |pattern, channel, event|
          relay_processor.call(channel, event)
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
      redis_subscriber.unsubscribe if redis_subscriber.subscribed?
      redis_thread.exit
      controller.terminate(event)
      redis_thread = nil
      ws = nil
    end

    ws.rack_response # async
  else
    [200, {"Content-Type" => "application/json"}, [Nostr::Nips::Nip11.call.to_json]]
  end
end
