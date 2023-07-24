module Nostr
  module Nips
    class Nip43
      def self.call(event)
        errors = []

        relay_tag = event["tags"].find { |t| t.first === "relay" }
        return [nil, ["Tag 'relay' is missing"]] unless relay_tag

        errors.push("Kind #{event["kind"]} is invalid for NIP-43 event, expected 22242") unless event["kind"] === 22242
        errors.push("Created At is too old, expected window is #{RELAY_CONFIG.fast_auth_window_seconds} seconds") if Time.at(event["created_at"].to_i + RELAY_CONFIG.fast_auth_window_seconds).past?
        errors.push("Created At is in the future") if Time.at(event["created_at"]).future?
        errors.push("Tag 'relay' has invalid value, expected #{RELAY_CONFIG.self_url}") unless URI.parse(relay_tag.second).host === URI.parse(RELAY_CONFIG.self_url).host

        serialized_event = [
          0,
          event["pubkey"],
          event["created_at"],
          event["kind"],
          event["tags"],
          event["content"]
        ]
        id_matches_payload = Digest::SHA256.hexdigest(JSON.dump(serialized_event)) === event["id"]

        errors.push("Id is invalid") unless id_matches_payload

        schnorr_params = {
          message: [event["id"]].pack("H*"),
          pubkey: [event["pubkey"]].pack("H*"),
          sig: [event["sig"]].pack("H*")
        }

        sig_matches_id = begin
          Secp256k1::SchnorrSignature.from_data(schnorr_params[:sig]).verify(schnorr_params[:message], Secp256k1::XOnlyPublicKey.from_data(schnorr_params[:pubkey]))
        rescue Secp256k1::DeserializationError
          false
        end

        errors.push("Signature is invalid") unless sig_matches_id

        if errors.present?
          [nil, errors]
        else
          [event["pubkey"], []]
        end
      rescue => e
        Sentry.capture_exception(e)
        [nil, ["something went wrong"]]
      end
    end
  end
end
