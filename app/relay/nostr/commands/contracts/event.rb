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
            schnorr_params = {
              message: [event["id"]].pack("H*"),
              pubkey: [event["pubkey"]].pack("H*"),
              sig: [event["sig"]].pack("H*")
            }

            sig_is_valid = begin
              Secp256k1::SchnorrSignature.from_data(schnorr_params[:sig]).verify(schnorr_params[:message], Secp256k1::XOnlyPublicKey.from_data(schnorr_params[:pubkey]))
            rescue Secp256k1::DeserializationError
              false
            end

            add_error("/0/sig", "property '/0/sig' doesn't match") unless sig_is_valid
          end
        end
      end
    end
  end
end
