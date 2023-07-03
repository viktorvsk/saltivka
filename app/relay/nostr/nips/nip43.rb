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

        schnorr_params = [
          [event["id"]].pack("H*"),
          [event["pubkey"]].pack("H*"),
          [event["sig"]].pack("H*")
        ]

        sig_matches_id = Schnorr.valid_sig?(*schnorr_params)

        errors.push("Signature is invalid") unless sig_matches_id

        if errors.present?
          [nil, errors]
        else
          [event["pubkey"], []]
        end
      end
    end
  end
end
