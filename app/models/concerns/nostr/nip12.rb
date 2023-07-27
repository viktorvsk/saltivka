module Nostr
  module Nip12
    extend ActiveSupport::Concern

    included do
      has_many :searchable_tags, autosave: true, dependent: :delete_all

      before_create :init_searchable_tags

      def init_searchable_tags
        if kinda?(:parameterized_replaceable) && tags.none? { |t| t.first === "d" }
          searchable_tags.new(name: "d", value: "")
        end
        tag_with_value_only = tags.map { |t| t[..1] }
        unique_tags = tag_with_value_only.uniq { |tag| tag[0] + tag[1..].map(&:downcase).sort.join }
        unique_tags.each do |tag|
          tag_name, tag_value = tag
          tag_value_too_long = tag_value && tag.second.size > RELAY_CONFIG.max_searchable_tag_value_length
          next if tag_value_too_long
          next if tag_name.size != 1 # NIP-12 populate searchable filters for every single letter tag
          tag_value ||= ""

          searchable_tags.new(name: tag_name, value: tag_value)
        end
      end
    end
  end
end
