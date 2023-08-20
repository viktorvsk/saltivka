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
      to_delete = [
        Event.where(author_id: author_id, kind: kind).where("events.created_at < ?", created_at).pluck(:id),
        Event.where(author_id: author_id, kind: kind, created_at: created_at).where("LOWER(events.sha256) > ?", sha256.downcase).pluck(:id)
      ].flatten.reject(&:blank?)

      Event.where(id: to_delete.uniq).destroy_all if to_delete.present?
    end

    def must_not_be_ephemeral_nip16
      return unless kinda?(:ephemeral)

      errors.add(:kind, "must not be ephemeral")

      throw(:abort)
    end

    def must_be_newer_than_existing_replaceable_nip16
      newer = Event.where(author_id: author_id, kind: kind).where("events.created_at > ?", created_at)

      lexically_lower = Event.where(author_id: author_id, kind: kind, created_at: created_at).where("LOWER(events.sha256) < ?", sha256.downcase)

      # We add such a strange error key in order for client to receive OK message with duplicate: prefix
      # We kinda say that "This event already exists" which is technically not true
      # because its a different event with different ID but since its replaceable
      # newer event is treated as "the same existing"
      errors.add(:sha256, "has already been taken") if newer.exists? || lexically_lower.exists?
    end
  end
end
