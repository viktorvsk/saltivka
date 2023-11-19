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
      event_was_deleted = DeleteEvent.where(author_id: author.id).where(sha256: sha256).exists?
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
      delete_events_to_upsert = events_ids_to_delete.map { |digest| {sha256: digest, author_id: author.id} }

      if events_ids_to_delete.present?
        DeleteEvent.upsert_all(delete_events_to_upsert, unique_by: %i[sha256 author_id])
        to_delete_events_ids = Event.where(author_id: author.id).where("LOWER(events.sha256) IN (?)", events_ids_to_delete).where.not(kind: 5).pluck(:id)
        Event.includes(:searchable_content).where(id: to_delete_events_ids).destroy_all
      end
    end
  end
end
