module Nostr
  module Nip42
    extend ActiveSupport::Concern

    included do
      validate :challenge_event_nip42, if: proc { |event| event.kind === 22242 }
    end

    private

    def challenge_event_nip42
      relay_tag = tags.find { |t| t.first === "relay" }
      challenge_tag = tags.find { |t| t.first === "challenge" }
      self_url_host = URI.parse(RELAY_CONFIG.self_url).host

      unless URI.parse(relay_tag.second.to_s).host === self_url_host
        errors.add(:tags, "'relay' must equal to #{self_url_host}")
      end

      if challenge_tag
        unless REDIS.sismember("connections", challenge_tag.second.to_s)
          errors.add(:tags, "'challenge' is invalid")
        end
      end

      if created_at.before?(RELAY_CONFIG.challenge_window_seconds.seconds.ago)
        errors.add(:created_at, "is too old, must be within #{RELAY_CONFIG.challenge_window_seconds} seconds")
      end
    end
  end
end
