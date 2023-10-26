Nostr::Relay = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env, [], extensions: WebsocketExtensions.all) # standard websocket connection object
    remote_ip = ActionDispatch::Request.new(env).remote_ip
    redis_subscriber = Redis.new(url: ENV["REDIS_URL"], driver: :hiredis)
    rate_limited = MemStore.with_redis { |redis| !redis.sismember("unlimited_ips", remote_ip) }
    controller = Nostr::RelayController.new(remote_ip: remote_ip, rate_limited: rate_limited)
    relay_response = Nostr::RelayResponse.new
    connection_id = controller.connection_id
    redis_thread = nil
    hearbeat_thread = nil
    last_active_at = Time.now.to_i

    ws.on :open do |event|
      Thread.new do
        MemStore.with_redis do |redis|
          maintenance, max_allowed_connections, connections_count = redis.pipelined do |pipeline|
            pipeline.get("maintenance")
            pipeline.get("max_allowed_connections")
            pipeline.scard("connections")
            pipeline.sadd("connections", connection_id)
            pipeline.hset("connections_ips", connection_id, controller.remote_ip)
            pipeline.hset("connections_starts", connection_id, Time.now.to_i.to_s)
          end

          ws.close(3503, "restricted: server is on maintenance, please try again later") if ActiveRecord::Type::Boolean.new.cast(maintenance)
          ws.close(3503, "restricted: server is busy, please try again later") if max_allowed_connections.to_i != 0 && connections_count.to_i >= max_allowed_connections.to_i
        end
      end

      Nostr::AuthenticationFlow.new.call(ws_url: ws.url, connection_id: connection_id) do |event|
        if event.first === "TERMINATE"
          ws.close(3403, "restricted: #{event.last}")
        else
          MemStore.with_redis { |redis| redis.hincrby("outgoing_traffic", connection_id, event.to_json.bytesize) }
          ws.send(event.to_json)
        end
      end

      redis_thread = Thread.new do
        redis_subscriber.psubscribe("events:#{connection_id}:*") do |on|
          on.pmessage do |pattern, channel, event|
            _namespace, _connection_id, subscription_id, command = channel.scan(/\A(.*):(\w+):(.*):(.*)\Z/).flatten

            if command.upcase === "TERMINATE"
              code, reason = JSON.parse(event)
              ws.close(code, reason)
              Thread.current.exit
            elsif command.upcase === "PING"
              Thread.current.exit unless ws.ping
            else
              MemStore.with_redis { |redis| redis.hincrby("outgoing_traffic", connection_id, event.to_json.bytesize) }
              ws.send(relay_response.call(command.upcase, subscription_id, event))
            end
          end
        end
      end

      hearbeat_thread = Thread.new do
        loop do
          sleep(RELAY_CONFIG.heartbeat_interval)
          MemStore.with_redis { |redis| redis.zremrangebyscore("requests:#{remote_ip}", "-inf", RELAY_CONFIG.rate_limiting_sliding_window.seconds.ago.to_i.to_s) }
          ws.close(3408, "Connection was idle for too long, max amount of time is #{RELAY_CONFIG.heartbeat_interval} seconds") if (Time.now.to_i - last_active_at) > RELAY_CONFIG.heartbeat_interval
        end
      end
    end

    ws.on :message do |event|
      last_active_at = Time.now.to_i
      controller.perform(event_data: event.data) do |notice|
        MemStore.with_redis { |redis| redis.hincrby("outgoing_traffic", connection_id, notice.bytesize) }
        ws.send(notice)
      end
    end

    ws.on :close do |event|
      redis_subscriber.punsubscribe if redis_subscriber.subscribed?
      controller.terminate(event: event, redis: redis_subscriber)
      redis_subscriber.disconnect!
      redis_thread&.exit
      hearbeat_thread&.exit
      redis_thread = nil
      ws = nil
      redis_subscriber = nil
    end

    ws.rack_response # async
  else
    [200, {"Content-Type" => "application/json"}, [Nostr::Nips::Nip11.call.to_json]]
  end
end
