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

      if rate_limited
        return block.call notice!("rate-limited: take it easy") if exceeds_window_quota?

        redis.pipelined do
          redis.zadd("requests:#{remote_ip}", ts, ts)
          redis.hincrby("requests", connection_id, 1)
          redis.hincrby("incoming_traffic", connection_id, event_data.bytesize)
        end
      end

      if event_data.bytesize > RELAY_CONFIG.max_message_length
        return block.call notice!("error: max allowed content length is #{RELAY_CONFIG.max_message_length} bytes")
      end

      nostr_event = JSON.parse(event_data)

      unless nostr_event.is_a?(Array)
        return block.call notice!("error: event must be an Array")
      end

      command = nostr_event[0]
      command_args = nostr_event[1..]

      if command.present? && command.upcase.in?(COMMANDS)
        contract_class = "Nostr::Commands::Contracts::#{command.downcase.classify}".constantize
        contract = contract_class.new
        contract_result = contract.call(nostr_event)
        if contract_result.success?
          controller_action = "#{command.downcase}_command"
          if authorized?(command, command_args)
            begin
              send(controller_action, command_args, block)
            rescue => e
              Sentry.capture_exception(e)
              block.call notice!("error: unknown error")
            end
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

      # TODO: for some reason it doesn't work in a separate pipelined call
      # at least in test env
      event22242_id = redis.hget("connections_authenticators", connection_id)
      subscriptions_keys = redis.keys("subscriptions:#{connection_id}:*")

      redis.pipelined do
        redis.del("client_reqs:#{connection_id}")
        redis.del(subscriptions_keys) if subscriptions_keys.present?
        redis.srem("connections", connection_id)
        redis.hdel("connections_authenticators", connection_id)
        redis.hdel("authentications", connection_id) # TODO: check why it wasn't here before
        redis.hdel("authorizations", connection_id)
        redis.hdel("requests", connection_id)
        redis.hdel("incoming_traffic", connection_id)
        redis.hdel("outgoing_traffic", connection_id)
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
      required_auth_level = RELAY_CONFIG.send("required_auth_level_for_#{command.downcase}")
      return true if required_auth_level.zero?
      return true if Nostr::Nips::Nip65.call(command, nostr_event)

      level = redis.hget("authorizations", connection_id).to_i # nil.to_i === 0
      level >= required_auth_level
    end

    def notice!(text)
      ["NOTICE", text].to_json
    end
  end
end
