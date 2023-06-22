module Nostr
  module Nip9
    extend ActiveSupport::Concern

    included do
      validate :validate_deleted_event_tags_nip_9, if: proc { |event| event.kind === 5 }
      before_create :process_delete_event_nip_9
    end

    private

    def validate_deleted_event_tags_nip_9
      unless tags.any? { |tag| tag.first === "e" && tag.last =~ /\A[0-9a-f]{64}\Z/ }
        errors.add(:tags, "must have valid 'e' entry for kind 5 DeleteEvent")
      end
    end

    def process_delete_event_nip_9
      return unless kind === 5

      events_ids_to_delete = tags.select { |tag| tag.first === "e" && tag.last =~ /\A[0-9a-f]{64}\Z/ }.map(&:last)
      events_ids_to_delete.each { |id_to_delete| DeleteEvent.where(pubkey: pubkey, id: id_to_delete).create }

      Event.where(pubkey: pubkey, id: events_ids_to_delete).destroy_all
    end
  end
end
