module Nostr
  module Nip1
    extend ActiveSupport::Concern

    included do
      validates :kind, presence: true
      validate :tags_must_be_array
      validate :id_must_match_payload
      validate :sig_must_match_payload

      belongs_to :author, autosave: true
      belongs_to :event_digest, autosave: true
      has_many :searchable_tags, autosave: true, dependent: :destroy

      before_create :init_searchable_tags

      delegate :pubkey, to: :author, allow_nil: true
      delegate :sha256, :schnorr, :pow_difficulty, to: :event_digest, allow_nil: true

      validates_associated :event_digest, :author, :searchable_tags

      def init_searchable_tags
        tags.each do |tag|
          tag_name = tag.first
          next unless tag_name.size === 1 # NIP-12 populate searchable filters for every single letter tag
          tag_values = tag[1..]
          tag_values = [""] if tag_values.blank?
          tag_values.each do |tag_value|
            searchable_tags.new(name: tag_name, value: tag_value)
          end
        end
      end

      def matches_nostr_filter_set?(filter_set)
        filter_set.transform_keys(&:downcase).slice(*RELAY_CONFIG.available_filters).all? do |filter_type, filter_value|
          case filter_type
          when "kinds"
            kind.in?(filter_value)
          when "ids"
            filter_value.any? { |prefix| event_digest.sha256.starts_with?(prefix) }
          when "authors"
            filter_value.any? do |prefix|
              return true if author.pubkey.starts_with?(prefix)

              delegation_tag = tags.find { |k, v| k === "delegation" }
              return false unless delegation_tag
              delegation_pubkety = [1..].flatten.second
              return delegation_pubkety.starts_with?(prefix)
            end
          when /\A#[a-z]\Z/
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
          created_at: created_at.to_i,
          id: sha256,
          sig: schnorr,
          tags: tags
        }
      end

      def pubkey=(value)
        (author || build_author).pubkey = value
      end

      def digest_and_sig=(arr)
        event_sha256, event_schnorr = arr

        build_event_digest(sha256: event_sha256)
        event_digest.build_sig(schnorr: event_schnorr)
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
          [schnorr].pack("H*")
        ]

        errors.add(:sig, "must match payload") unless Schnorr.valid_sig?(*schnorr_params)
      end
    end

    class_methods do
      def by_nostr_filters(filter_set, subscriber_pubkey = nil)
        rel = all.select(:id).order(created_at: :desc)
        filter_set.stringify_keys!

        unless filter_set["kinds"].present?
          rel = rel.where.not(kind: 4)
        end

        filter_set.select { |key, value| value.present? }.each do |key, value|
          value = Array.wrap(value)
          if key == "kinds"
            if value.include?(4)
              value.delete(4)
              rel = if subscriber_pubkey.present?
                rel.where("events.kind IN (:kinds) OR (events.kind = 4 AND (authors.pubkey = :pubkey OR (searchable_tags.name = 'p' AND searchable_tags.value = :pubkey)))", kinds: value, pubkey: subscriber_pubkey)
              else
                rel.where(kind: value)
              end
            else
              rel = rel.where(kind: value)
            end
          end

          if key == "ids"
            rel = rel.joins(:event_digest).where("event_digests.sha256 ILIKE ANY (ARRAY[?])", value.map { |id| "#{id}%" })
          end

          if key == "authors"
            # NIP-26
            authors_to_search = value.map { |author| "#{author}%" }
            rel = rel.joins(:author)
              .joins("LEFT JOIN searchable_tags ON searchable_tags.event_id = events.id AND searchable_tags.name = 'delegation'")
              .where("(authors.pubkey ILIKE ANY (ARRAY[:values])) OR (searchable_tags.value ILIKE ANY (ARRAY[:values]))", values: authors_to_search)
          end

          if key == "#e"
            rel = rel.joins(:searchable_tags).where("searchable_tags.name = 'e' AND searchable_tags.value ILIKE ANY (ARRAY[?])", value.map { |t| "#{t}%" })
          end

          if key == "#p"
            rel = rel.joins(:searchable_tags).where("searchable_tags.name = 'p' AND searchable_tags.value ILIKE ANY (ARRAY[?])", value.map { |t| "#{t}%" })
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
