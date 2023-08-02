module Nostr
  module Nip1
    extend ActiveSupport::Concern

    included do
      validates :kind, presence: true
      validate :tags_must_be_array
      validate :id_must_match_payload, if: proc { |_event| RELAY_CONFIG.validate_id_on_server }
      validate :sig_must_match_payload, if: proc { |_event| RELAY_CONFIG.validate_sig_on_server }
      validate :lower_sha256_uniqueness, on: :create
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
        author_from_pubkey = begin
          Author.select(:id, :pubkey).where("LOWER(authors.pubkey) = ?", value).first_or_create(pubkey: value)
        rescue ActiveRecord::RecordNotUnique
          Author.select(:id, :pubkey).where("LOWER(authors.pubkey) = ?", value).first
        end

        self.author = author_from_pubkey
      end

      def created_at=(value)
        value.is_a?(Numeric) ? super(Time.at(value)) : super(value)
      end

      private

      def lower_sha256_uniqueness
        if Event.where("LOWER(events.sha256) = ?", sha256).exists?
          errors.add(:sha256, "has already been taken")
        end
      end

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
      def by_nostr_filters(filter_set, subscriber_pubkey = nil, count_request = nil)
        rel = if count_request
          all.select(:id).distinct(:id)
        else
          all.select("events.id, events.created_at").distinct(:id).order("events.created_at DESC, events.id DESC")
        end
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
                        events.kind = 4 AND (LOWER(authors.pubkey) = :pubkey OR LOWER(delegator_authors.pubkey) = :pubkey OR LOWER(p_tags.value) = :pubkey)
                      )
                  SQL
                  # NIP-26
                  # TODO: check performance
                  rel
                    .joins(:author)
                    .joins("LEFT JOIN searchable_tags AS p_tags ON p_tags.event_id = events.id AND p_tags.name = 'p'")
                    .joins("LEFT JOIN event_delegators ON event_delegators.event_id = events.id")
                    .joins("LEFT JOIN authors AS delegator_authors ON delegator_authors.id = event_delegators.author_id")
                    .where(where_clause, kinds: value, pubkey: subscriber_pubkey.downcase)
                else
                  rel
                    .joins(:author)
                    .joins("LEFT JOIN searchable_tags AS p_tags ON p_tags.event_id = events.id AND p_tags.name = 'p'")
                    .joins("LEFT JOIN event_delegators ON event_delegators.event_id = events.id")
                    .joins("LEFT JOIN authors AS delegator_authors ON delegator_authors.id = event_delegators.author_id")
                    .where("events.kind = 4 AND (LOWER(authors.pubkey) = :pubkey OR LOWER(delegator_authors.pubkey) = :pubkey OR LOWER(p_tags.value) = :pubkey)", pubkey: subscriber_pubkey.downcase)
                end
              else
                rel.where(kind: value)
              end
            else
              rel = rel.where(kind: value)
            end
          end

          if key == "ids"
            # sha256 max length is 64 so we don't need a predicate match in this case
            where_clause = value.uniq.map { |id| "LOWER(events.sha256) #{(id.length == 64) ? "=" : "^@"} '#{id.downcase}'" }.join(" OR ")

            rel = rel.where(where_clause)
          end

          if key == "authors"
            # pubkey max length is 64 so we don't need a predicate match in this case
            where_clause = value.uniq.map { |pubkey| "LOWER(authors.pubkey) #{(pubkey.length == 64) ? "=" : "^@"} '#{pubkey.downcase}'" }.join(" OR ")

            rel = rel.joins(:author).where(where_clause)
          end

          if /\A#[a-zA-Z]\Z/.match?(key)
            # value of #e and #p tags max length is 64 so we don't need a predicate match in this case
            where_clause = value.map do |t|
              if key.last.in?(%w[e p])
                "LOWER(searchable_tags.value) #{(t.length == 64) ? "=" : "^@"} '#{t.downcase}'"
              else
                "LOWER(searchable_tags.value) ^@ '#{t.downcase}'"
              end
            end
            where_clause = where_clause.join(" OR ")

            rel = rel.joins(:searchable_tags).where(searchable_tags: {name: key.last}).where(where_clause)
          end

          rel = rel.where("created_at >= ?", Time.at(value)) if key == "since"
          rel = rel.where("created_at <= ?", Time.at(value)) if key == "until"
        end

        filter_limit = if count_request
          nil
        elsif filter_set["limit"].to_i > 0
          [filter_set["limit"].to_i, RELAY_CONFIG.max_limit].min
        else
          RELAY_CONFIG.default_filter_limit
        end

        if filter_set.key?("authors")

          # NIP-26

          # pubkey max length is 64 so we don't need a predicate match in this case
          where_clause = filter_set["authors"].map { |pubkey| "LOWER(delegator_authors.pubkey) #{(pubkey.length == 64) ? "=" : "^@"} '#{pubkey.downcase}'" }.join(" OR ")

          delegator_rel = by_nostr_filters(filter_set.except("authors"), subscriber_pubkey, count_request).joins(:author)
            .joins("LEFT JOIN event_delegators ON event_delegators.event_id = events.id")
            .joins("LEFT JOIN authors AS delegator_authors ON delegator_authors.id = event_delegators.author_id")
            .where(where_clause)
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
