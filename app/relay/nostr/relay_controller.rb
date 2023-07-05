module Nostr
  class RelayController
    include Nostr::Nips::Nip1
    include Nostr::Nips::Nip45

    attr_reader :redis, :connection_id

    COMMANDS = %w[REQ CLOSE EVENT COUNT]

    def initialize(connection_id = nil)
      @connection_id = connection_id || SecureRandom.hex
    end

    def perform(event_data:, redis:, &block)
      Rails.logger.info(event_data)
      @redis = redis
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
        redis.call("SET", "events22242:#{event22242_id}", "", "KEEPTTL")
      end
    end

    private

    def authorized?(command, nostr_event)
      return true if Nostr::Nips::Nip65.call(command, nostr_event)

      level = redis.hget("authorizations", connection_id).to_i # nil.to_i === 0
      level >= RELAY_CONFIG.send("required_auth_level_for_#{command.downcase}")
    end

    def notice!(text)
      ["NOTICE", text].to_json
    end

    def sidekiq_pusher
      @sidekiq_pusher ||= lambda do |klass, args|
        Sidekiq::Client.push({
          "retry" => true,
          "backtrace" => false,
          "queue" => :nostr,
          "class" => klass,
          "args" => args
        })
      end
    end
  end
end
