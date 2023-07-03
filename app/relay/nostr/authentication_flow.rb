module Nostr
  class AuthenticationFlow
    def self.call(ws_url:, connection_id:, redis:)
      # TODO: Use BLPOP if NIP-43 is enforced
      auth_event_22242 = CGI.unescape(CGI.parse(URI.parse(ws_url).query.to_s)["authorization"].first.to_s)
      if auth_event_22242.present?
        event = JSON.parse(auth_event_22242)
        pubkey, errors = Nostr::Nips::Nip43.call(event)
        if errors.present?
          yield ["NOTICE", "error: #{errors.join(", ")}"].to_json if block_given?
        else
          redis.multi do
            # Possible options here are: [nil, "", "<vald_pubkey>"]
            # nil means key was expired and it should be impossible to authenticate with this event
            # since we don't allow created_at in the future and expiration is set to the value of allowed window
            # "" means connection was closed but key is not expired yet
            # "<valid_pubkey>" means client is active
            # We want to keep this key as is when connection is closed elsewhere
            # and let it expire naturally in order to prevent next situation
            # 1) User authenticates with Event22242
            # 2) User leaves immediately, before auth window config passed
            # 3) MiTM attacker authenticates with the same event
            # And another more real case where
            # 1) User authenticates with Event22242
            # 2) MiTM attacker authenticates with the same event
            # 3) Both get disconnected immediately
            # 4) User doesn't notice it and leaves (or its client generates new Event22242 for auth)
            # 5) Attacker authenticates successfully again immediately before window time passed
            existing_connection_id = redis.get("events22242:#{event["id"]}")

            if existing_connection_id.nil?
              redis.call("SET", "events22242:#{event["id"]}", connection_id, "EX", RELAY_CONFIG.fast_auth_window_seconds.to_s)
              redis.hset("connections_authenticators", connection_id, event["id"])
              redis.hset("authentications", connection_id, pubkey)
            else
              # Here we handle MiTM attacker trying to authenticate with the same
              # event 22242 by terminating current connection
              redis.publish("events:#{connection_id}:_:terminate", [403, "This event was used for authentication twice"].to_json)

              # We also terminate connection previously authenticated with this event
              # if it was not disconnected on its own yet
              if existing_connection_id.present?
                redis.publish("events:#{existing_connection_id}:_:terminate", [403, "This event was used for authentication twice"].to_json)
                redis.hdel("connections_authenticators", connection_id)
                redis.hdel("authentications", existing_connection_id)
              end
            end
          end
        end
      elsif block_given?
        yield ["AUTH", connection_id].to_json
      end
      # NIP-42

      pubkey
    rescue JSON::ParserError => e
      yield ["NOTICE", "error: #{e.message}"].to_json if block_given?
    end
  end
end
