module Nostr
  module Nip50
    extend ActiveSupport::Concern

    CONTENT_SEARCHABLE_KINDS = RELAY_CONFIG.content_searchable_kinds

    included do
      before_create do
        if kind.in?(CONTENT_SEARCHABLE_KINDS)
          searchable_content = build_searchable_content(language: SearchableContent::DEFAULT_LANGUAGE)
          searchable_content.tsv_content = content.downcase
        end
      end

      has_one :searchable_content, autosave: true, dependent: :delete

      def self.by_search_query(query)
        mod, text = query.scan(/\A(?:m:(\w+))?(.*)\Z/).flatten.map(&:strip)
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

        if ts_function == "to_tsquery"
          begin
            ActiveRecord::Base.transaction do
              ActiveRecord::Base.connection.execute("SELECT to_tsquery('#{text}')")
            end
          rescue ActiveRecord::StatementInvalid => _
            return Event.none
          end
        end

        joins(:searchable_content).where("searchable_contents.tsv_content @@ #{ts_function}(?)", text.downcase)
      end
    end
  end
end
