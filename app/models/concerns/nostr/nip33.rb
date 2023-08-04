# TODO: Add specs

module Nostr
  module Nip33
    extend ActiveSupport::Concern

    included do
      before_validation :process_replaceable_parameterized_nip33, if: ->(event) { event.kinda?(:parameterized_replaceable) }
      validate :must_be_newer_than_existing_parameterized_replaceable_nip33, if: ->(event) { event.kinda?(:parameterized_replaceable) }
    end

    private

    def process_replaceable_parameterized_nip33
      d_tag = tags.find { |t| t.first === "d" } || ["d"]

      d_tag_value = d_tag.second.to_s

      to_delete = [
        Event.joins(:searchable_tags).where("LOWER(searchable_tags.value) = ?", d_tag_value.downcase).where(author_id: Author.select(:id).where("LOWER(pubkey) = ?", pubkey), kind: kind, searchable_tags: {name: "d"}).where("events.created_at < ?", created_at).pluck(:id),
        Event.joins(:searchable_tags).where("LOWER(searchable_tags.value) = ?", d_tag_value.downcase).where(author_id: Author.select(:id).where("LOWER(pubkey) = ?", pubkey), kind: kind, created_at: created_at, searchable_tags: {name: "d"}).where("LOWER(events.sha256) > ?", sha256.downcase).pluck(:id)
      ].flatten.reject(&:blank?)

      Event.where(id: to_delete).destroy_all
    end

    def must_be_newer_than_existing_parameterized_replaceable_nip33
      should_not_save = false

      d_tag = tags.find { |t| t.first === "d" } || ["d"]

      d_tag_value = d_tag.second.to_s

      newer_exists = Event.joins(:searchable_tags)
        .where(author_id: Author.select(:id).where("LOWER(pubkey) = ?", pubkey), searchable_tags: {name: "d"}, kind: kind)
        .where("LOWER(searchable_tags.value) = ?", d_tag_value.downcase)
        .where("events.created_at > ?", created_at).exists?
      should_not_save = true if newer_exists

      # Looks a bit ugly but in this we only make second check if required
      should_not_save ||= Event.joins(:searchable_tags)
        .where(author_id: Author.select(:id).where("LOWER(pubkey) = ?", pubkey), searchable_tags: {name: "d"}, kind: kind, created_at: created_at)
        .where("LOWER(searchable_tags.value) = ?", d_tag_value.downcase)
        .where("LOWER(events.sha256) < ?", sha256.downcase).exists?

      # We add such a strange error key in order for client to receive OK message with duplicate: prefix
      # We kinda say that "This event already exists" which is technically not true
      # because its a different event with different ID but since its replaceable
      # newer event is treated as "the same existing"
      errors.add(:sha256, "has already been taken") if should_not_save
    end
  end
end
