Nostr::Relay = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)
    ws_sender = lambda { |string| ws.send(string) }
    pubsub_callback = lambda do |on|
      on.message do |channel, event|
        subscription_id = channel.split(":").last

        if event === "EOSE"
          ws.send(["EOSE", subscription_id].to_json)
        else
          ws.send(["EVENT", subscription_id, event].to_json)
        end
      end
    end
    listener_service = RedisPubsubListener.new(pubsub_callback)
    controller = Nostr::RelayController.new(ws_sender: ws_sender, listener_service: listener_service, redis: REDIS)

    ws.on :message do |event|
      controller.perform(event.data)
    end

    ws.on :close do |event|
      controller.terminate(event)
      ws = nil
    end

    ws.rack_response
  else
    [200, {"Content-Type" => "text/plain"}, ["Hello"]]
  end
end
