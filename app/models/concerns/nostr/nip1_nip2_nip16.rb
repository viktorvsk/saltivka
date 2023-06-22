module Nostr
  module Nip1Nip2Nip16
    extend ActiveSupport::Concern

    included do
      before_create :process_replaceable_nip_1_nip_2_nip_16
    end

    private

    def process_replaceable_nip_1_nip_2_nip_16
      return unless kinda?(:replaceable)

      Event.where(pubkey: pubkey, kind: kind).where("created_at < ?", created_at).destroy_all
    end
  end
end
