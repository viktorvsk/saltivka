module Nostr
  module Nip26
    extend ActiveSupport::Concern

    included do
      validate :validate_delegation_nip26
      has_one :event_delegator, dependent: :destroy
      before_create do
        if tags.any? { |t| t.first === "delegation" }

          delegator_pubkey = tags.find { |t| t.first === "delegation" }.second

          build_event_delegator(author: Author.from_pubkey(delegator_pubkey))
        end
      end

      def delegation_tag_pubkey
        tags.find { |t| t.first == "delegation" }&.second
      end

      private

      def validate_delegation_nip26
        return if tags.none? { |t| t.first === "delegation" }

        delegation_tag = tags.find { |t| t.first === "delegation" }
        delegation_pubkey, condition_string, delegation_sig = delegation_tag[1..]
        delegation_string = "nostr:delegation:#{delegation_pubkey}:#{condition_string}"

        schnorr_params = {
          message: [Digest::SHA256.hexdigest(delegation_string)].pack("H*"),
          pubkey: [delegation_pubkey].pack("H*"),
          sig: [delegation_sig].pack("H*")
        }

        delegated_kinds = condition_string.scan(/kind=(\d{1,})/)
        min_created_at = condition_string.scan(/created_at>(\d{1,})/).flatten.first&.to_i
        max_created_at = condition_string.scan(/created_at<(\d{1,})/).flatten.first&.to_i

        if delegated_kinds && !kind.to_s.in?(delegated_kinds.flatten)
          errors.add(:tags, "'delegation' kind doesn't allow kind #{kind}")
        end
        if min_created_at && created_at.to_i < min_created_at
          errors.add(:tags, "'delegation' created_at < event created_at minimum")
        end
        if max_created_at && created_at.to_i > max_created_at
          errors.add(:tags, "'delegation' created_at > event created_at maximum")
        end
        unless /\A[0-9a-f]{64}\Z/.match?(delegation_pubkey)
          errors.add(:tags, "'delegation' pubkey must be a valid 64 characters hex")
        end

        sig_is_valid = begin
          Secp256k1::SchnorrSignature.from_data(schnorr_params[:sig]).verify(schnorr_params[:message], Secp256k1::XOnlyPublicKey.from_data(schnorr_params[:pubkey]))
        rescue Secp256k1::DeserializationError
          false
        end

        unless sig_is_valid
          errors.add(:tags, "'delegation' signature must be valid")
        end
      end
    end
  end
end
