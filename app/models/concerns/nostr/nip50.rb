module Nostr
  module Nip50
    extend ActiveSupport::Concern

    CONTENT_SEARCHABLE_KINDS = RELAY_CONFIG.content_searchable_kinds

    included do
      before_create do
        if kind.in?(CONTENT_SEARCHABLE_KINDS)
          searchable_content = build_searchable_content(language: SearchableContent::DEFAULT_LANGUAGE)
          searchable_content.tsv_content = content.downcase
          # TODO: check if errors in searchable_content prevents parent event record from saving
          # it may happen for instance when kind-1 event has content but after it becomes tsv_content
          # it is empty because it was removed as stop words in used dictionary
        end
      end

      has_one :searchable_content, autosave: true, dependent: :delete

      def self.by_search_query(query)
        ts_function, text = parse_nip50_query(query)

        if ts_function == "to_tsquery"
          begin
            ActiveRecord::Base.transaction do
              Event.where("to_tsvector('test') @@ #{ts_function}(?)", text).exists?
            end
          rescue ActiveRecord::StatementInvalid => _
            return Event.none
          end
        end

        where(events: {id: SearchableContent.select(:event_id).where("tsv_content @@ #{ts_function}(?)", text).order(tsv_content: :desc)})
      end

      def matches_full_text_search?(query)
        ts_function, text = self.class.parse_nip50_query(query)
        result = nil

        if ts_function == "to_tsquery"
          begin
            ActiveRecord::Base.transaction do
              result = Event.where("to_tsvector(?) @@ #{ts_function}(?)", content, text).exists?
            end
          rescue ActiveRecord::StatementInvalid => e
            Rails.logger.warn("[InvalidSearchQuery][#{e.class}] message=#{e.message} query=#{query}")
            result = false
          end
        end

        result
      end

      def self.parse_nip50_query(query)
        mod, text = query.scan(/\A(?:m:(\w+))?(.*)\Z/m).flatten.map(&:to_s).map(&:strip)

        case mod
        when "plain"
          ts_function, text = "plainto_tsquery", text
        when "phrase"
          ts_function, text = "phraseto_tsquery", text
        when "manual"
          ts_function, text = "to_tsquery", text
        when "prefix"
          ts_function, text = "to_tsquery", text.split(" ").map { |word| "#{word}:*" }.join(" ")
        else
          ts_function, text = "websearch_to_tsquery", text
        end

        [ts_function, text.downcase]
      end
    end
  end
end
