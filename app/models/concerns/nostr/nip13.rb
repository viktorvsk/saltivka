module Nostr
  module Nip13
    extend ActiveSupport::Concern

    included do
      validate :proof_of_work_nip13
    end

    def pow_difficulty
      @pow_difficulty ||= begin
        binary_id = [sha256].pack("H*").unpack1("B*")
        zeroes = binary_id.gsub(/^(0+)?.*/, '\1')
        zeroes.length
      end
    end

    private

    def proof_of_work_nip13
      if RELAY_CONFIG.min_pow > pow_difficulty
        errors.add(:sha256, "PoW difficulty must be at least #{RELAY_CONFIG.min_pow}, got #{pow_difficulty}")
      end
    end
  end
end
