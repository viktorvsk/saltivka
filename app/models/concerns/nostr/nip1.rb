module Nostr
  module Nip1
    KNOWN_KINDS_TYPES = %w[set_metadata text_note recommend_server delete_event protocol_reserved replaceable ephemeral private parameterized_replaceable unknown]
    AVAILABLE_FILTERS = SubscriptionQueryBuilder::AVAILABLE_FILTERS.map { |filter_name| /\A[a-zA-Z]\Z/.match?(filter_name) ? "##{filter_name}" : filter_name }

    extend ActiveSupport::Concern

    included do
      before_validation :delete_older_replaceable, if: ->(event) { event.kinda?(:replaceable) }
      before_validation :delete_older_parameterized_replaceable, if: ->(event) { event.kinda?(:parameterized_replaceable) }

      before_create :init_searchable_tags

      before_save :must_not_be_ephemeral

      validates :kind, presence: true
      validates :sig, presence: true, length: {is: 128}
      validates :sha256, presence: true, length: {is: 64}
      validates :content, length: {maximum: RELAY_CONFIG.max_content_length}

      validate :tags_must_be_array
      validate :id_must_match_payload, if: proc { |_event| RELAY_CONFIG.validate_id_on_server }
      validate :sig_must_match_payload, if: proc { |_event| RELAY_CONFIG.validate_sig_on_server }
      validate :lower_sha256_uniqueness, on: :create
      validate :must_be_newer_than_existing_replaceable, if: ->(event) { event.kinda?(:replaceable) }
      validate :must_be_newer_than_existing_parameterized_replaceable, if: ->(event) { event.kinda?(:parameterized_replaceable) }

      belongs_to :author, autosave: true
      has_many :searchable_tags, autosave: true, dependent: :delete_all

      delegate :pubkey, to: :author, allow_nil: true

      validates_associated :author

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

          # create searchable tags for every single-letter tag
          next if tag_name.size != 1
          next unless /\A[a-zA-Z]\Z/.match?(tag_name)
          tag_value ||= ""

          searchable_tags.new(name: tag_name, value: tag_value)
        end
      end

      def single_letter_tags
        tags.select { |t| t.first =~ /\A[a-zA-Z]\Z/ }.map { |t| [t[0], t[1]] }
      end

      def kinda?(event_type)
        raise "Unknown event kind type" unless event_type.to_s.downcase.in?(KNOWN_KINDS_TYPES)

        kind_types = case kind
        when 0
          %w[set_metadata protocol_reserved replaceable]
        when 1
          %w[text_note protocol_reserved]
        when 2
          %w[recommend_server protocol_reserved]
        when 3
          %w[contact_list protocol_reserved replaceable]
        when 5
          %w[delete_event protocol_reserved]
        when 41
          %w[channel_metadata replaceable protocol_reserved]
        when 0...1000
          %w[protocol_reserved]
        when 1000...10000
          %w[regular]
        when 10000...20000
          %w[replaceable]
        when 22242
          %w[ephemeral private]
        when 20000...30000
          %w[ephemeral]
        when 30000...40000
          %w[parameterized_replaceable]
        else
          %w[unknown]
        end

        event_type.to_s.in?(kind_types)
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

      def delete_older_replaceable
        to_delete = [
          Event.where(author_id: author_id, kind: kind).where("events.created_at < ?", created_at).pluck(:id),
          Event.where(author_id: author_id, kind: kind, created_at: created_at).where("LOWER(events.sha256) > ?", sha256.downcase).pluck(:id)
        ].flatten.reject(&:blank?)

        Event.where(id: to_delete.uniq).destroy_all if to_delete.present?
      end

      def must_not_be_ephemeral
        return unless kinda?(:ephemeral)

        errors.add(:kind, "must not be ephemeral")

        throw(:abort)
      end

      def must_be_newer_than_existing_replaceable
        newer = Event.where(author_id: author_id, kind: kind).where("events.created_at > ?", created_at)

        lexically_lower = Event.where(author_id: author_id, kind: kind, created_at: created_at).where("LOWER(events.sha256) < ?", sha256.downcase)

        # We add such a strange error key in order for client to receive OK message with duplicate: prefix
        # We kinda say that "This event already exists" which is technically not true
        # because its a different event with different ID but since its replaceable
        # newer event is treated as "the same existing"
        errors.add(:sha256, "has already been taken") if newer.exists? || lexically_lower.exists?
      end

      def delete_older_parameterized_replaceable
        d_tag = tags.find { |t| t.first === "d" } || ["d"]

        d_tag_value = d_tag.second.to_s

        to_delete = [
          Event.joins(:searchable_tags).where("LOWER(searchable_tags.value) = ?", d_tag_value.downcase).where(author_id: author_id, kind: kind, searchable_tags: {name: "d"}).where("events.created_at < ?", created_at).pluck(:id),
          Event.joins(:searchable_tags).where("LOWER(searchable_tags.value) = ?", d_tag_value.downcase).where(author_id: author_id, kind: kind, created_at: created_at, searchable_tags: {name: "d"}).where("LOWER(events.sha256) > ?", sha256.downcase).pluck(:id)
        ].flatten.reject(&:blank?)

        Event.where(id: to_delete).destroy_all
      end

      def must_be_newer_than_existing_parameterized_replaceable
        d_tag = tags.find { |t| t.first === "d" } || ["d"]

        d_tag_value = d_tag.second.to_s

        newer = Event.joins(:searchable_tags)
          .where(author_id: author_id, searchable_tags: {name: "d"}, kind: kind)
          .where("LOWER(searchable_tags.value) = ?", d_tag_value.downcase)
          .where("events.created_at > ?", created_at)

        lexically_lower = Event.joins(:searchable_tags)
          .where(author_id: author_id, searchable_tags: {name: "d"}, kind: kind, created_at: created_at)
          .where("LOWER(searchable_tags.value) = ?", d_tag_value.downcase)
          .where("LOWER(events.sha256) < ?", sha256.downcase)

        # We add such a strange error key in order for client to receive OK message with duplicate: prefix
        # We kinda say that "This event already exists" which is technically not true
        # because its a different event with different ID but since its replaceable
        # newer event is treated as "the same existing"
        errors.add(:sha256, "has already been taken") if newer.exists? || lexically_lower.exists?
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

        filter_set.transform_keys(&:downcase).slice(*AVAILABLE_FILTERS).select { |key, value| value.present? }.each do |key, value|
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
            where_clause = value.uniq.map { |id| "LOWER(events.sha256) = ?" }.join(" OR ")

            rel = rel.where(where_clause, *value.uniq.map(&:downcase))
          end

          if key == "authors"
            # pubkey max length is 64 so we don't need a predicate match in this case
            where_clause = value.uniq.map { |pubkey| "LOWER(authors.pubkey) = ?" }.join(" OR ")

            rel = rel.joins(:author).where(where_clause, *value.uniq.map(&:downcase))
          end

          if /\A#[a-zA-Z]\Z/.match?(key)
            where_clause = value.map { |t| "LOWER(searchable_tags.value) = ?" }.join(" OR ")

            rel = rel.joins(:searchable_tags).where(searchable_tags: {name: key.last}).where(where_clause, *value.map(&:downcase))
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
          where_clause = filter_set["authors"].map { |pubkey| "LOWER(delegator_authors.pubkey) = ?" }.join(" OR ")

          delegator_rel = by_nostr_filters(filter_set.except("authors"), subscriber_pubkey, count_request).joins(:author)
            .joins("LEFT JOIN event_delegators ON event_delegators.event_id = events.id")
            .joins("LEFT JOIN authors AS delegator_authors ON delegator_authors.id = event_delegators.author_id")
            .where(where_clause, *filter_set["authors"].map(&:downcase))
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
