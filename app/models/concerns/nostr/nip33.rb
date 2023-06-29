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

      # Event.joins(:author, :searchable_tags, :event_digest).where(authors: {pubkey: pubkey}, searchable_tags: {name: "d", value: d_tag_value}, kind: kind).where("created_at < ?", created_at).destroy_all
      # Event.joins(:author, :searchable_tags, :event_digest).where(authors: {pubkey: pubkey}, searchable_tags: {name: "d", value: d_tag_value}, kind: kind, created_at: created_at).where("event_digests.sha256 > ?", sha256).destroy_all

      EventDigest.joins(:author, event: :searchable_tags).where(authors: {pubkey: pubkey}, events: {kind: kind}, searchable_tags: {name: "d", value: d_tag_value}).where("events.created_at < ?", created_at).destroy_all
      EventDigest.joins(:author, event: :searchable_tags).where(authors: {pubkey: pubkey}, events: {kind: kind, created_at: created_at}, searchable_tags: {name: "d", value: d_tag_value}).where("event_digests.sha256 > ?", sha256).destroy_all
    end

    def must_be_newer_than_existing_parameterized_replaceable_nip33
      should_not_save = false

      d_tag = tags.find { |t| t.first === "d" } || ["d"]

      d_tag_value = d_tag.second.to_s

      newer_exists = Event.joins(:author, :searchable_tags).where(authors: {pubkey: pubkey}, searchable_tags: {name: "d", value: d_tag_value}, kind: kind).where("events.created_at > ?", created_at).exists?
      should_not_save = true if newer_exists

      # Looks a bit ugly but in this we only make second check if required
      should_not_save ||= EventDigest.joins(:author, event: :searchable_tags).where(authors: {pubkey: pubkey}, searchable_tags: {name: "d", value: d_tag_value}, events: {kind: kind, created_at: created_at}).where("event_digests.sha256 < ?", sha256).exists?

      # We add such a strange error key in order for client to receive OK message with duplicate: prefix
      # We kinda say that "This event already exists" which is technically not true
      # because its a different event with different ID but since its replaceable
      # newer event is treated as "the same existing"
      errors.add(:"event_digest.sha256", "has already been taken") if should_not_save
    end
  end
end
