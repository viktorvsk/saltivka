module Nostr
  module Nip1Nip2Nip16
    extend ActiveSupport::Concern

    included do
      before_validation :process_replaceable_nip_1_nip_2_nip_16, if: ->(event) { event.kinda?(:replaceable) }

      before_save :must_not_be_ephemeral_nip16
      validate :must_be_newer_than_existing_replaceable_nip16, if: ->(event) { event.kinda?(:replaceable) }
    end

    private

    def process_replaceable_nip_1_nip_2_nip_16
      EventDigest.joins(:author, :event).where(authors: {pubkey: author.pubkey}, events: {kind: kind}).where("events.created_at < ?", created_at).destroy_all
      EventDigest.joins(:author, :event).where(authors: {pubkey: author.pubkey}, events: {kind: kind, created_at: created_at}).where("event_digests.sha256 > ?", sha256).destroy_all
    end

    def must_not_be_ephemeral_nip16
      return unless kinda?(:ephemeral)

      errors.add(:kind, "must not be ephemeral")

      throw(:abort)
    end

    def must_be_newer_than_existing_replaceable_nip16
      should_not_save = false

      newer_exists = Event.joins(:author).where(authors: {pubkey: pubkey}, kind: kind).where("events.created_at > ?", created_at).exists?
      should_not_save = true if newer_exists

      # Looks a bit ugly but in this we only make second check if required
      should_not_save ||= EventDigest.joins(:author, :event).where(authors: {pubkey: author.pubkey}, events: {kind: kind, created_at: created_at}).where("event_digests.sha256 < ?", sha256).exists?

      # We add such a strange error key in order for client to receive OK message with duplicate: prefix
      # We kinda say that "This event already exists" which is technically not true
      # because its a different event with different ID but since its replaceable
      # newer event is treated as "the same existing"
      errors.add(:"event_digest.sha256", "has already been taken") if should_not_save
    end
  end
end
