module Nostr
  module Nip33
    extend ActiveSupport::Concern

    included do
      before_create :process_replaceable_parameterized_nip33
    end

    private

    def process_replaceable_parameterized_nip33
      return unless kinda?(:parameterized)

      d_tag_value = tags.select { |k, v| k === "d" }.values.flatten.first

      if d_tag_value.present?
        Event.joins(:author, :searchable_tags).where(authors: {pubkey: author.pubkey}, searchable_tags: {name: "d", value: d_tag_value}, kind: kind).where("created_at < ?", created_at).destroy_all
        # TODO: Remove event with the same created_at but "bigger" sha256
      else
        Event.joins(:author, :searchable_tags).where(authors: {pubkey: author.pubkey}, searchable_tags: {name: "d", value: ["", nil]}, kind: kind).where("created_at < ?", created_at).destroy_all
        Event.joins(:author).joins("LEFT JOIN searchable_tags ON events.id = searchable_tags.event_id AND searchable_tags.name = 'd' ").where(authors: {pubkey: author.pubkey}, searchable_tags: {value: nil}, kind: kind).where("created_at < ?", created_at).destroy_all
        # TODO: Remove event with the same created_at but "bigger" sha256
      end
    end
  end
end
