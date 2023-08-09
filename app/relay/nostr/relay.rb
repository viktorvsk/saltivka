Nostr::Relay = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env, [], extensions: WebsocketExtensions.all) # standard websocket connection object
    remote_ip = ActionDispatch::Request.new(env).remote_ip
    redis_subscriber = Redis.new(url: ENV["REDIS_URL"], driver: :hiredis)
    rate_limited = Sidekiq.redis { |c| c.sismember("unlimited_ips", remote_ip).zero? }
    controller = Nostr::RelayController.new(remote_ip: remote_ip, rate_limited: rate_limited)
    relay_response = Nostr::RelayResponse.new
    connection_id = controller.connection_id
    redis_thread = nil
    hearbeat_thread = nil
    last_active_at = Time.now.to_i

    ws.on :open do |event|
      Thread.new do
        Sidekiq.redis do |c|
          maintenance, max_allowed_connections, connections_count = c.pipelined do
            c.get("maintenance")
            c.get("max_allowed_connections")
            c.scard("connections")
            c.sadd("connections", connection_id)
            c.hset("connections_ips", connection_id, controller.remote_ip)
            c.hset("connections_starts", connection_id, Time.now.to_i.to_s)
          end

          ws.close(3503, "restricted: server is on maintenance, please try again later") if ActiveRecord::Type::Boolean.new.cast(maintenance)
          ws.close(3503, "restricted: server is busy, please try again later") if max_allowed_connections.to_i != 0 && connections_count.to_i >= max_allowed_connections.to_i
        end
      end

      Sidekiq.redis do |c|
        Nostr::AuthenticationFlow.new.call(ws_url: ws.url, connection_id: connection_id, redis: c) do |event|
          if event.first === "TERMINATE"
            ws.close(3403, "restricted: #{event.last}")
          else
            c.hincrby("outgoing_traffic", connection_id, event.to_json.bytesize)
            ws.send(event.to_json)
          end
        end
      end

      redis_thread = Thread.new do
        redis_subscriber.psubscribe("events:#{connection_id}:*") do |on|
          on.pmessage do |pattern, channel, event|
            _namespace, _connection_id, subscription_id, command = channel.split(":")

            if command.upcase === "TERMINATE"
              code, reason = JSON.parse(event)
              ws.close(code, reason)
              Thread.current.exit
            else
              Sidekiq.redis { |redis_connection| redis_connection.hincrby("outgoing_traffic", connection_id, event.to_json.bytesize) }
              ws.send(relay_response.call(command.upcase, subscription_id, event))
            end
          end
        end
      end

      hearbeat_thread = Thread.new do
        loop do
          ws.close(3408, "Connection was idle for too long, max amount of time is #{RELAY_CONFIG.heartbeat_interval} seconds") if (Time.now.to_i - last_active_at) > RELAY_CONFIG.heartbeat_interval
          sleep(RELAY_CONFIG.heartbeat_interval)
        end
      end
    end

    ws.on :message do |event|
      last_active_at = Time.now.to_i
      Sidekiq.redis do |redis_connection|
        controller.perform(event_data: event.data, redis: redis_connection) do |notice|
          redis_connection.hincrby("outgoing_traffic", connection_id, notice.bytesize)
          ws.send(notice)
        end
      end
    end

    ws.on :close do |event|
      redis_subscriber.unsubscribe if redis_subscriber.subscribed?
      controller.terminate(event: event, redis: redis_subscriber)
      redis_thread&.exit
      hearbeat_thread&.exit
      redis_thread = nil
      ws = nil
    end

    ws.rack_response # async
  else
    [200, {"Content-Type" => "application/json"}, [Nostr::Nips::Nip11.call.to_json]]
  end
end
