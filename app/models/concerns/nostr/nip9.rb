module Nostr
  module Nip9
    extend ActiveSupport::Concern

    included do
      validate :validate_deleted_event_tags_nip_9, if: proc { |event| event.kind === 5 }
      validate :must_not_store_deleted_event, unless: proc { |event| event.kind === 5 }
      before_create :process_delete_event_nip_9, if: proc { |event| event.kind === 5 }
    end

    private

    def must_not_store_deleted_event
      event_was_deleted = DeleteEvent.joins(:author).where(authors: {pubkey: pubkey}, sha256: sha256).exists?
      errors.add(:id, "is already listed as deleted") if event_was_deleted
    end

    def validate_deleted_event_tags_nip_9
      e_tag = tags.find { |t| t.first === "e" }
      unless e_tag
        errors.add(:tags, "must have 'e' entry for kind 5 event (DeleteEvent)")
        return
      end

      delete_event_sha256 = e_tag.last.to_s

      unless /\A[0-9a-f]{64}\Z/.match?(delete_event_sha256)
        errors.add(:tags, "'e' tag must have a valid hex pubkey as a last (and second) element for kind 5 event (DeleteEvent)")
      end
    end

    def process_delete_event_nip_9
      events_ids_to_delete = tags.select { |tag| tag.first === "e" && tag.last =~ /\A[0-9a-f]{64}\Z/ }.map(&:last)
      events_ids_to_delete.each do |id_to_delete|
        ApplicationRecord.transaction do
          author = Author.create_or_find_by!(pubkey: pubkey)
          DeleteEvent.create_or_find_by!(author: author, sha256: id_to_delete)
        end
      end

      Event.joins(:author).where(authors: {pubkey: pubkey}, sha256: events_ids_to_delete).where.not(kind: 5).destroy_all
    end
  end
end
