module Nostr
  module Nip40
    extend ActiveSupport::Concern

    included do
      validate :not_expired_nip40
      after_commit :destroy_expired_events_nip40
    end

    private

    def not_expired_nip40
      expiration_tag = tags.find { |t| t.first === "expiration" }

      return unless expiration_tag

      expires_at = expiration_tag.second.to_i

      errors.add(:base, "was expired on #{Time.at(expires_at).strftime("%c")}") if Time.at(expires_at).past?
    end

    def destroy_expired_events_nip40
      expiration_tag = tags.find { |t| t.first === "expiration" }

      return unless expiration_tag

      expires_at = expiration_tag.second.to_i

      DeleteExpiredEventNip40.perform_at(expires_at, sha256) if Time.at(expires_at).future?
    end
  end
end
