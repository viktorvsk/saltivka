module Nostr
  class RelayController
    include Nostr::Nips::Nip1
    include Nostr::Nips::Nip45

    attr_reader :redis, :connection_id, :remote_ip, :rate_limited

    COMMANDS = %w[REQ CLOSE EVENT COUNT]

    def initialize(remote_ip: nil, rate_limited: true, connection_id: nil)
      @connection_id = connection_id || SecureRandom.hex
      @remote_ip = remote_ip || "127.0.0.1"
      @rate_limited = rate_limited
    end

    def perform(event_data:, redis:, &block)
      Rails.logger.info(event_data)
      @redis = redis
      ts = Time.now.to_i

      return block.call notice!("rate-limited: take it easy") if rate_limited && exceeds_window_quota?

      redis.multi do |t|
        t.zadd("requests:#{remote_ip}", ts, ts)
        t.hincrby("requests", connection_id, 1)
        t.hincrby("traffic", connection_id, event_data.bytesize)
      end

      if event_data.bytesize > RELAY_CONFIG.max_message_length
        return block.call notice!("error: max allowed content length is #{RELAY_CONFIG.max_message_length} bytes")
      end

      nostr_event = JSON.parse(event_data)

      unless nostr_event.is_a?(Array)
        return block.call notice!("error: event must be an Array")
      end

      command = nostr_event.shift

      if command.present? && command.upcase.in?(COMMANDS)
        contract_class = "Nostr::Commands::Contracts::#{command.downcase.classify}".constantize
        contract = contract_class.new
        contract_result = contract.call(nostr_event)
        if contract_result.success?
          controller_action = "#{command.downcase}_command"
          if authorized?(command, nostr_event)
            send(controller_action, nostr_event, block)
          else
            block.call notice!("restricted: your account doesn't have required authorization level")
          end
        else
          error = Presenters::Errors.new(contract_result.errors.to_h)
          block.call notice!("error: #{error}")
        end
      else
        error = Presenters::Errors.new(command: %(unexpected command: '#{command}'))
        block.call notice!("error: #{error}")
      end
    rescue JSON::ParserError
      error = Presenters::Errors.new(json: %(malformed JSON))
      block.call notice!("error: #{error}")
    end

    def terminate(event:, redis:)
      Rails.logger.info("[TERMINATING] connection_id=#{connection_id}")

      redis.multi do
        pubsub_ids = redis.smembers("client_reqs:#{connection_id}").map { |req| "#{connection_id}:#{req}" }
        event22242_id = redis.hget("connections_authenticators", connection_id)

        redis.del("client_reqs:#{connection_id}")
        redis.srem("connections", connection_id)
        redis.hdel("connections_authenticators", connection_id)
        redis.hdel("subscriptions", pubsub_ids) if pubsub_ids.present?
        redis.hdel("authentications", connection_id) # TODO: check why it wasn't here before
        redis.hdel("authorizations", connection_id)
        redis.hdel("requests", connection_id)
        redis.hdel("traffic", connection_id)
        redis.hdel("connections_ips", connection_id)
        redis.hdel("connections_starts", connection_id)
        redis.call("SET", "events22242:#{event22242_id}", "", "KEEPTTL")
      end
    end

    private

    def exceeds_window_quota?
      requests_count_in_time_window = redis.zcount("requests:#{remote_ip}", RELAY_CONFIG.rate_limiting_sliding_window.seconds.ago.to_i, "+inf").to_i
      requests_count_in_time_window > RELAY_CONFIG.rate_limiting_max_requests
    end

    def authorized?(command, nostr_event)
      return true if Nostr::Nips::Nip65.call(command, nostr_event)

      level = redis.hget("authorizations", connection_id).to_i # nil.to_i === 0
      level >= RELAY_CONFIG.send("required_auth_level_for_#{command.downcase}")
    end

    def notice!(text)
      ["NOTICE", text].to_json
    end
  end
end
