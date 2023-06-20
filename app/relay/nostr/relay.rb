Nostr::Relay = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env) # standard websocket connection object

    # We use this lambda to minimize what Controller may have access to
    ws_sender = lambda do |string|
      ws.send(string)
    end

    # Server side events logic
    server_events_handler = Nostr::RelayProcessor.new(ws_sender)

    # Simple object that controles Redis connection in a separate thread and
    # allows adding or removing channels (subscriptions) that are listened to
    listener_service = RedisPubsubListener.new(server_events_handler)

    relay_context = {
      ws_sender: ws_sender,
      listener_service: listener_service,
      redis: REDIS
    }
    controller = Nostr::RelayController.new(**relay_context)

    # Client side events logic
    ws.on :message do |event|
      controller.perform(event.data)
    end

    ws.on :close do |event|
      controller.terminate(event)
      ws = nil
    end

    ws.rack_response # async
  else
    [200, {"Content-Type" => "text/plain"}, ["Hello"]]
  end
end
