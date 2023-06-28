module Nostr
  module Nip26
    extend ActiveSupport::Concern

    included do
      validate :validate_delegation_nip26

      private

      def validate_delegation_nip26
        return if tags.none? { |t| t.first === "delegation" }

        delegation_tag = tags.find { |t| t.first === "delegation" }
        delegation_pubkey, condition_string, delegation_sig = delegation_tag[1..]
        delegation_string = "nostr:delegation:#{delegation_pubkey}:#{condition_string}"

        schnorr_params = [
          [Digest::SHA256.hexdigest(delegation_string)].pack("H*"),
          [delegation_pubkey].pack("H*"),
          [delegation_sig].pack("H*")
        ]

        delegated_kinds = condition_string.scan(/kind=(\d{1,})/)
        min_created_at = condition_string.scan(/created_at>(\d{1,})/).flatten.first.to_i
        max_created_at = condition_string.scan(/created_at<(\d{1,})/).flatten.first.to_i

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

        unless Schnorr.valid_sig?(*schnorr_params)
          errors.add(:tags, "'delegation' signature must be valid")
        end
      end
    end
  end
end
