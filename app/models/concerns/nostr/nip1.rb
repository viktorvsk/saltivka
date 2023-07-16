module Nostr
  module Nip1
    extend ActiveSupport::Concern

    included do
      validates :kind, presence: true
      validate :tags_must_be_array
      validate :id_must_match_payload, if: proc { |_event| RELAY_CONFIG.validate_id_on_server }
      validate :sig_must_match_payload, if: proc { |_event| RELAY_CONFIG.validate_sig_on_server }
      validates :sig, presence: true, length: {is: 128}
      validates :sha256, presence: true, length: {is: 64}
      validates :content, length: {maximum: RELAY_CONFIG.max_content_length}

      belongs_to :author, autosave: true

      delegate :pubkey, to: :author, allow_nil: true

      validates_associated :author

      def matches_nostr_filter_set?(filter_set)
        filter_set.transform_keys(&:downcase).slice(*RELAY_CONFIG.available_filters).all? do |filter_type, filter_value|
          case filter_type
          when "kinds"
            # We don't check relation between the subscriber authenticated pubkey
            # and event's pubkey or p tag or delegation because this will be
            # check right before sending event to listeners if it matches their filters
            kind.in?(filter_value)
          when "ids"
            filter_value.any? { |prefix| sha256.starts_with?(prefix) }
          when "authors"
            filter_value.any? do |prefix|
              return true if pubkey.starts_with?(prefix)

              # NIP-26
              delegation_tag = tags.find { |k, v| k === "delegation" }
              return false unless delegation_tag
              return delegation_tag.second.starts_with?(prefix)
            end
          when /\A#[a-zA-Z]\Z/
            # NIP-12 search single letter filters
            filter_value.any? do |prefix|
              searchable_tags.any? do |t|
                t.name == filter_type.last && t.value.starts_with?(prefix)
              end
            end
          when "since"
            created_at.to_i >= filter_value
          when "until"
            created_at.to_i <= filter_value
          else
            Rails.logger.warn("Unhandled available filter: #{filter_type}")
            false
          end
        end
      end

      def to_nostr_serialized
        [
          0,
          pubkey,
          created_at.to_i,
          kind,
          tags,
          content.to_s
        ]
      end

      def as_json(options = nil)
        {
          kind:,
          content:,
          pubkey:,
          sig:,
          created_at: created_at.to_i,
          id: sha256,
          tags: tags
        }
      end

      def pubkey=(value)
        self.author = Author.create_or_find_by(pubkey: value)
      end

      def created_at=(value)
        value.is_a?(Numeric) ? super(Time.at(value)) : super(value)
      end

      private

      def tags_must_be_array
        errors.add(:tags, "must be an array") unless tags.is_a?(Array)
      end

      def id_must_match_payload
        errors.add(:id, "must match payload") unless Digest::SHA256.hexdigest(JSON.dump(to_nostr_serialized)) === sha256
      end

      def sig_must_match_payload
        schnorr_params = [
          [sha256].pack("H*"),
          [pubkey].pack("H*"),
          [sig].pack("H*")
        ]

        errors.add(:sig, "must match payload") unless Schnorr.valid_sig?(*schnorr_params)
      end
    end

    class_methods do
      def by_nostr_filters(filter_set, subscriber_pubkey = nil)
        rel = all.distinct(:id).order(created_at: :desc)
        filter_set.stringify_keys!

        if RELAY_CONFIG.enforce_kind_4_authentication && filter_set["kinds"].blank?
          rel = rel.where.not(kind: 4)
        end

        filter_set.transform_keys(&:downcase).slice(*RELAY_CONFIG.available_filters).select { |key, value| value.present? }.each do |key, value|
          if key == "kinds"
            value = Array.wrap(value)
            if RELAY_CONFIG.enforce_kind_4_authentication && value.include?(4)
              value.delete(4)
              if value.blank? && subscriber_pubkey.blank?
                rel = rel.where.not(kind: 4)
                next
              end

              rel = if subscriber_pubkey.present?
                if value.present?
                  where_clause = <<~SQL
                    events.kind IN (:kinds) OR
                      (
                        events.kind = 4 AND (authors.pubkey = :pubkey OR delegation_or_p_tags.value = :pubkey)
                      )
                  SQL
                  rel.joins(:author).joins("LEFT JOIN searchable_tags AS delegation_or_p_tags ON delegation_or_p_tags.event_id = events.id AND delegation_or_p_tags.name IN ('p', 'delegation')").where(where_clause, kinds: value, pubkey: subscriber_pubkey)
                else
                  rel.joins(:author).joins("LEFT JOIN searchable_tags AS delegation_or_p_tags ON delegation_or_p_tags.event_id = events.id AND delegation_or_p_tags.name IN ('p', 'delegation')").where("events.kind = 4 AND (authors.pubkey = :pubkey OR delegation_or_p_tags.value = :pubkey)", pubkey: subscriber_pubkey)
                end
              else
                rel.where(kind: value)
              end
            else
              rel = rel.where(kind: value)
            end
          end

          if key == "ids"
            rel = rel.where("UPPER(events.sha256) LIKE ANY (ARRAY[?])", value.map { |id| "#{id}%".upcase })
          end

          if key == "authors"
            # NIP-26
            authors_to_search = value.map { |author| "#{author}%".upcase }
            where_clause = <<~SQL
              (
                UPPER(authors.pubkey) LIKE ANY (ARRAY[:values])) OR
                  (
                    UPPER(delegation_tags.value) LIKE ANY (ARRAY[:values]
                  )
              )
            SQL
            rel = rel.joins(:author)
              .joins("LEFT JOIN searchable_tags AS delegation_tags ON delegation_tags.event_id = events.id AND delegation_tags.name = 'delegation'")
              .where(where_clause, values: authors_to_search)
          end

          if /\A#[a-zA-Z]\Z/.match?(key)
            # NIP-12 + #e #p #d
            rel = rel.joins(:searchable_tags).where("searchable_tags.name = '#{key.last}' AND UPPER(searchable_tags.value) LIKE ANY (ARRAY[?])", value.map { |t| "#{t}%".upcase })
          end

          rel = rel.where("created_at >= ?", Time.at(value)) if key == "since"
          rel = rel.where("created_at <= ?", Time.at(value)) if key == "until"
        end

        filter_limit = if filter_set["limit"].to_i > 0
          [filter_set["limit"].to_i, RELAY_CONFIG.max_limit].min
        else
          RELAY_CONFIG.default_filter_limit
        end

        rel.limit(filter_limit)
      end
    end
  end
end
