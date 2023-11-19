module Nostr
  module Nips
    module Nip42
      private

      def auth_command(nostr_event, block)
        auth_event_22242 = CGI.escape(nostr_event.first.to_json)

        # We don't care about actual URL structure at this point and just reuse
        # existing component. We emulate NIP-43 AUTH but do not terminate connection
        # in case of errors
        ws_url = "ws://example.com?authorization=#{auth_event_22242}"

        Nostr::AuthenticationFlow.new.call(ws_url: ws_url, connection_id: connection_id) do |event|
          case event.first
          when "TERMINATE", "NOTICE"
            MemStore.fanout(cid: connection_id, command: :notice, payload: event.last)
          else
            Rails.logger.warn("[Nostr::AuthenticationFlow][NIP-42] Unknown event: #{event}")
          end
        end
      end
    end
  end
end
