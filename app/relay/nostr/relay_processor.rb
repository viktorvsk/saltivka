module Nostr
  class RelayProcessor
    def self.call(channel, event)
      _namespace, _connection_id, subscription_id, command = channel.split(":")

      response = case command.upcase
      when "FOUND_END"
        ["EOSE", subscription_id].to_json
      when "FOUND_EVENT"
        ["EVENT", subscription_id, JSON.parse(event)].to_json
      when "OK"
        event # NIP-20
      end

      Rails.logger.info("[Nostr::RelayProcessor] response=#{response}")
      response
    end
  end
end
