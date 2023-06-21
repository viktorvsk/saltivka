require "schnorr"

module Nostr
  class RelayController
    include Nostr::Nips::Nip1

    attr_reader :ws_sender, :listener_service, :redis

    COMMANDS = %w[REQ CLOSE EVENT]

    def initialize(ws_sender:, listener_service:, redis:)
      @ws_sender = ws_sender
      @listener_service = listener_service
      @redis = redis
    end

    def perform(event_data)
      Rails.logger.info(event_data)
      nostr_event = JSON.parse(event_data)
      command = nostr_event.shift
      if command.present? && command.upcase.in?(COMMANDS)
        contract_class = "Nostr::Commands::Contracts::#{command.downcase.classify}".constantize
        contract = contract_class.new
        contract_result = contract.call(nostr_event)
        if contract_result.success?
          controller_action = "#{command.downcase}_command"
          send(controller_action, nostr_event)
        else
          error = Presenters::Errors.new(contract_result.errors.to_h)
          notice!("error: #{error}")
        end
      else
        error = Presenters::Errors.new(command: %(unexpected command: '#{command}'))
        notice!("error: #{error}")
      end
    rescue JSON::ParserError
      error = Presenters::Errors.new(json: %(malformed JSON))
      notice!("error: #{error}")
    end

    def terminate(_event)
      listener_service.unsubscribe
      clean_connections_data
    end

    private

    def clean_connections_data
      redis.multi do
        connection_subscriptions = redis.smembers("client_reqs:#{connection_id}")
        redis.del("client_reqs:#{connection_id}")
        redis.hdel("subscriptions", connection_subscriptions.map { |req| "#{connection_id}:#{req}" }) if connection_subscriptions.present?
      end
    end

    def notice!(text)
      ws_sender.call(["NOTICE", text].to_json)
    end

    def connection_id
      @connection_id ||= SecureRandom.hex
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
