Nostr::Relay = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env) # standard websocket connection object

    redis_subscriber = Redis.new(url: ENV["REDIS_URL"], driver: :hiredis)
    controller = Nostr::RelayController.new
    relay_response = Nostr::RelayResponse.new(ws: ws)
    connection_id = controller.connection_id
    redis_thread = nil
    hearbeat_thread = nil
    last_active_at = Time.now.to_i

    ws.on :open do |event|
      maintenance, max_allowed_connections, connections_count = redis_subscriber.multi do |t|
        t.get("maintenance")
        t.get("max_allowed_connections")
        t.scard("connections")
      end

      ws.close(3503, "restricted: server is on maintenance, please try again later") if ActiveRecord::Type::Boolean.new.cast(maintenance)
      ws.close(3503, "restricted: server is busy, please try again later") if max_allowed_connections.to_i != 0 && connections_count.to_i >= max_allowed_connections.to_i

      Nostr::AuthenticationFlow.new.call(ws_url: ws.url, connection_id: connection_id, redis: redis_subscriber) do |event|
        if event.first === "TERMINATE"
          ws.close(3403, "restricted: #{event.last}")
        else
          ws.send(event.to_json)
        end
      end

      redis_subscriber.sadd("connections", connection_id)

      redis_thread = Thread.new do
        redis_subscriber.psubscribe("events:#{connection_id}:*") do |on|
          on.pmessage do |pattern, channel, event|
            relay_response.call(channel, event)
          end
        end
      end

      hearbeat_thread = Thread.new do
        loop do
          ws.close(3408, "Connection was idle for too long, max amount of time is #{RELAY_CONFIG.heartbeat_interval} seconds") if (Time.now.to_i - last_active_at) > 5
          sleep(RELAY_CONFIG.heartbeat_interval)
        end
      end
    end

    ws.on :message do |event|
      last_active_at = Time.now.to_i
      Sidekiq.redis do |redis_connection|
        controller.perform(event_data: event.data, redis: redis_connection) do |notice|
          ws.send(notice)
        end
      end
    end

    ws.on :close do |event|
      redis_subscriber.unsubscribe if redis_subscriber.subscribed?
      redis_thread&.exit
      hearbeat_thread&.exit
      controller.terminate(event: event, redis: redis_subscriber)
      redis_thread = nil
      ws = nil
    end

    ws.rack_response # async
  else
    [200, {"Content-Type" => "application/json"}, [Nostr::Nips::Nip11.call.to_json]]
  end
end
