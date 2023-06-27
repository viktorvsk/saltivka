require "schnorr"

module Nostr
  class RelayController
    include Nostr::Nips::Nip1
    include Nostr::Nips::Nip45

    attr_reader :redis, :connection_id

    COMMANDS = %w[REQ CLOSE EVENT COUNT]

    def initialize(redis:)
      @redis = redis
      @connection_id = SecureRandom.hex
    end

    def perform(event_data, &block)
      Rails.logger.info(event_data)
      nostr_event = JSON.parse(event_data)
      command = nostr_event.shift
      if command.present? && command.upcase.in?(COMMANDS)
        contract_class = "Nostr::Commands::Contracts::#{command.downcase.classify}".constantize
        contract = contract_class.new
        contract_result = contract.call(nostr_event)
        if contract_result.success?
          controller_action = "#{command.downcase}_command"
          send(controller_action, nostr_event, block)
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

    private

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
