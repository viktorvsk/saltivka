module Nostr
  module Commands
    module Contracts
      class Event < Base
        private

        def schema
          Nostr::EVENT_SCHEMA
        end

        def validate_dependent(nostr_event)
          # we are confident its exactly event here because we run this validation only if schema is correct
          event = nostr_event.first

          serialized_event = [
            0,
            event["pubkey"],
            event["created_at"],
            event["kind"],
            event["tags"],
            event["content"]
          ]

          id_is_valid = Digest::SHA256.hexdigest(JSON.dump(serialized_event)) === event["id"]

          add_error("/0/id", "property '/0/id' doesn't match") unless id_is_valid

          if event["id"].present? && id_is_valid
            schnorr_params = [
              [event["id"]].pack("H*"),
              [event["pubkey"]].pack("H*"),
              [event["sig"]].pack("H*")
            ]
            add_error("/0/sig", "property '/0/sig' doesn't match") unless Schnorr.valid_sig?(*schnorr_params)
          end
        end
      end
    end
  end
end
