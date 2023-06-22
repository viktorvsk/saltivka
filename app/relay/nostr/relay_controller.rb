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
          yield notice!("error: #{error}") if block_given?
        end
      else
        error = Presenters::Errors.new(command: %(unexpected command: '#{command}'))
        yield notice!("error: #{error}") if block_given?
      end
    rescue JSON::ParserError
      error = Presenters::Errors.new(json: %(malformed JSON))
      yield notice!("error: #{error}") if block_given?
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
