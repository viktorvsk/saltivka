module Nostr
  class RelayResponse
    def call(command, subscription_id, event)
      case command.upcase
      when "FOUND_END"
        ["EOSE", subscription_id].to_json
      when "FOUND_EVENT"
        ["EVENT", subscription_id, JSON.parse(event)].to_json
      when "OK"
        event
      when "COUNT"
        ["COUNT", subscription_id, {count: event.to_i}].to_json
      when "NOTICE"
        ["NOTICE", event].to_json
      end
    end
  end
end
