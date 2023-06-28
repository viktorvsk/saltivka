module Nostr
  module Nip40
    extend ActiveSupport::Concern

    included do
      validate :not_already_expired_nip40
      after_commit :destroy_expired_events_nip40
    end

    private

    def not_already_expired_nip40
      expiration_tag = tags.find { |t| t.first === "expiration" }

      return unless expiration_tag

      expires_at = expiration_tag.last
      if expires_at.to_i.to_s != expires_at.to_s
        errors.add(:tags, "'expiration' must be unix timestamp")
      end

      if Time.at(expires_at.to_i).past?
        errors.add(:tags, "'expiration' value is in the past #{Time.at(expires_at.to_i).strftime("%c")}")
      end
    end

    def destroy_expired_events_nip40
      expiration_tag = tags.find { |t| t.first === "expiration" }

      return unless expiration_tag
      expires_at = expiration_tag.last

      DeleteExpiredEventNip40.perform_at(expires_at, sha256) if Time.at(expires_at.to_i).future?
    end
  end
end
