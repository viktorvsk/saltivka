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
        schnorr_params = {
          message: [sha256].pack("H*"),
          pubkey: [pubkey].pack("H*"),
          sig: [sig].pack("H*")
        }

        sig_is_valid = begin
          Secp256k1::SchnorrSignature.from_data(schnorr_params[:sig]).verify(schnorr_params[:message], Secp256k1::XOnlyPublicKey.from_data(schnorr_params[:pubkey]))
        rescue Secp256k1::DeserializationError
          false
        end

        errors.add(:sig, "must match payload") unless sig_is_valid
      end
    end

    class_methods do
      def by_nostr_filters(filter_set, subscriber_pubkey = nil)
        rel = all.select("events.id, events.created_at").distinct(:id).order("events.created_at DESC, events.id DESC")
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
                        events.kind = 4 AND (authors.pubkey = :pubkey OR delegator_authors.pubkey = :pubkey OR p_tags.value = :pubkey)
                      )
                  SQL
                  # NIP-26
                  # TODO: check performance
                  rel
                    .joins(:author)
                    .joins("LEFT JOIN searchable_tags AS p_tags ON p_tags.event_id = events.id AND p_tags.name = 'p'")
                    .joins("LEFT JOIN event_delegators ON event_delegators.event_id = events.id")
                    .joins("LEFT JOIN authors AS delegator_authors ON delegator_authors.id = event_delegators.author_id")
                    .where(where_clause, kinds: value, pubkey: subscriber_pubkey)
                else
                  rel
                    .joins(:author)
                    .joins("LEFT JOIN searchable_tags AS p_tags ON p_tags.event_id = events.id AND p_tags.name = 'p'")
                    .joins("LEFT JOIN event_delegators ON event_delegators.event_id = events.id")
                    .joins("LEFT JOIN authors AS delegator_authors ON delegator_authors.id = event_delegators.author_id")
                    .where("events.kind = 4 AND (authors.pubkey = :pubkey OR delegator_authors.pubkey = :pubkey OR p_tags.value = :pubkey)", pubkey: subscriber_pubkey)
                end
              else
                rel.where(kind: value)
              end
            else
              rel = rel.where(kind: value)
            end
          end

          if key == "ids"
            rel = rel.where("events.sha256 LIKE ANY (ARRAY[?])", value.map { |id| "#{id}%" })
          end

          if key == "authors"
            authors_to_search = value.map { |author| "#{author}%" }
            rel = rel.joins(:author).where("authors.pubkey LIKE ANY (ARRAY[:values])", values: authors_to_search)
          end

          if /\A#[a-zA-Z]\Z/.match?(key)
            # NIP-12 + #e #p #d
            rel = rel.joins(:searchable_tags).where("searchable_tags.name = '#{key.last}' AND searchable_tags.value LIKE ANY (ARRAY[?])", value.map { |t| "#{t}%" })
          end

          rel = rel.where("created_at >= ?", Time.at(value)) if key == "since"
          rel = rel.where("created_at <= ?", Time.at(value)) if key == "until"
        end

        filter_limit = if filter_set["limit"].to_i > 0
          [filter_set["limit"].to_i, RELAY_CONFIG.max_limit].min
        else
          RELAY_CONFIG.default_filter_limit
        end

        if filter_set.key?("authors")

          # NIP-26
          authors_to_search = filter_set["authors"].map { |author| "#{author}%" }

          delegator_rel = by_nostr_filters(filter_set.except("authors"), subscriber_pubkey).joins(:author)
            .joins("LEFT JOIN event_delegators ON event_delegators.event_id = events.id")
            .joins("LEFT JOIN authors AS delegator_authors ON delegator_authors.id = event_delegators.author_id")
            .where("delegator_authors.pubkey LIKE ANY (ARRAY[:values])", values: authors_to_search)

          union = <<~SQL
            (#{rel.limit(filter_limit).to_sql})

            UNION

            (#{delegator_rel.limit(filter_limit).to_sql})
          SQL

          LazySql.new(klass: "Event", sql: union)

        else
          rel.limit(filter_limit)
        end
      end
    end
  end
end
