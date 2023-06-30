module Nostr
  class RelayProcessor
    attr_reader :ws

    def initialize(ws:)
      @ws = ws
    end

    def call(channel, event)
      _namespace, _connection_id, subscription_id, command = channel.split(":")

      if command.upcase === "TERMINATE"
        code, reason = JSON.parse(event)
        ws.close(code, reason)
      else
        response = case command.upcase
        when "FOUND_END"
          ["EOSE", subscription_id].to_json
        when "FOUND_EVENT"
          ["EVENT", subscription_id, JSON.parse(event)].to_json
        when "OK"
          event # NIP-20
        when "COUNT"
          ["COUNT", subscription_id, {count: event.to_i}].to_json
        when "NOTICE"
          ["NOTICE", event].to_json
        end

        Rails.logger.info("[Nostr::RelayProcessor] response=#{response}")
        ws.send(response)
      end

      response
    end
  end
end
