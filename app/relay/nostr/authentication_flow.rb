module Nostr
  class AuthenticationFlow
    def call(ws_url:, connection_id:, redis:)
      auth_event_22242 = CGI.unescape(CGI.parse(URI.parse(ws_url).query.to_s)["authorization"].first.to_s).presence

      event = begin
        JSON.parse(auth_event_22242) if auth_event_22242
      rescue JSON::ParserError => e
        return yield(terminate("NIP-43 auth event has errors in JSON: #{e.message}"))
      end

      pubkey, errors = Nostr::Nips::Nip43.call(event) if auth_event_22242

      if RELAY_CONFIG.forced_min_auth_level > 0 # force NIP-43
        return yield(terminate("NIP-43 is forced over NIP-42 and auth event is missing in URL")) unless auth_event_22242
        return yield(terminate("NIP-43 is forced over NIP-42 and auth event has errors: #{Nostr::Presenters::Errors.new(errors)}")) if errors.present?
      else
        return yield(["AUTH", connection_id]) unless auth_event_22242 # NIP-42 fallback if no auth event provided
        return yield(terminate("NIP-43 auth attempt is detected but auth event has errors: #{Nostr::Presenters::Errors.new(errors)}")) if errors.present?
      end

      # Here we have a valid NIP-43 auth event present so the result is either
      # connection(s) termination or a succesful authorization (even if auth_level is 0)

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
          # Happy path/main flow
          redis.call("SET", "events22242:#{event["id"]}", connection_id, "EX", RELAY_CONFIG.fast_auth_window_seconds.to_s)
          redis.hset("connections_authenticators", connection_id, event["id"])
          redis.hset("authentications", connection_id, pubkey)

          # put event to Sidekiq
          redis.lpush("queue:nostr", {class: "AuthorizationRequest", args: [connection_id, event["id"], event["pubkey"]]}.to_json)

          if RELAY_CONFIG.forced_min_auth_level > 0
            # Synchronous authorization
            _list_name, authorization_level = redis.blpop("authorization_result:#{connection_id}", RELAY_CONFIG.authorization_timeout.to_s)

            if authorization_level.to_i < RELAY_CONFIG.forced_min_auth_level
              yield(terminate("your account doesn't have required authorization (#{RELAY_CONFIG.forced_min_auth_level})"))
            end
          end
        else
          # mitigating MiTM attack by closing both connections because we don't
          # know which of two connections is actually honest

          # Terminate connection previously authenticated with this event
          # if it has not been disconnected on its own yet
          if existing_connection_id.present?
            redis.publish("events:#{existing_connection_id}:_:terminate", [3403, "restricted: event with id #{event["id"]} was used for authentication twice"].to_json)
            redis.hdel("connections_authenticators", connection_id)
            redis.hdel("authentications", existing_connection_id)
          end

          # Terminate current connection
          yield(terminate("event with id #{event["id"]} was used for authentication twice"))
        end
      end
    rescue => e
      Sentry.capture_exception(e)
      Sentry.capture_message("[AuthenticationFlow][NotAuthorized][#{e.class}] event=#{event.to_json}", level: :warning)
      if RELAY_CONFIG.forced_min_auth_level > 0 # force NIP-43
        yield(terminate("NIP-43 is forced over NIP-42 and something went wrong"))
      else
        yield(["NOTICE", "error: #{e.class} #{e.message}"])
      end
    end

    private

    def terminate(msg)
      ["TERMINATE", msg]
    end
  end
end
