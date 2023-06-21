module Nostr
  class RelayProcessor
    def initialize(ws_sender)
      @ws_sender = ws_sender
    end

    def call(channel, event)
      subscription_id = channel.split(":").last

      response = if event === "EOSE"
        ["EOSE", subscription_id].to_json
      else
        ["EVENT", subscription_id, JSON.parse(event)].to_json
      end

      @ws_sender.call(response)

      response
    end
  end
end
