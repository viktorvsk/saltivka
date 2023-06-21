class Event < ApplicationRecord
  MAX_FILTER_LIMIT = ENV.fetch("MAX_FILTER_LIMIT", 1000)
  DEFAULT_FILTER_LIMIT = ENV.fetch("DEFAULT_FILTER_LIMIT", 100)
  AVAILABLE_FILTERS = %w[kinds ids authors #e #p since until]

  validates :pubkey, :kind, :sig, presence: true
  validates :id, :pubkey, length: {is: 64}
  validates :sig, length: {is: 128}
  validate :tags_must_be_array
  validate :id_must_match_payload
  validate :sig_must_match_payload

  def self.by_nostr_filters(filter_set)
    rel = all.select(:id)
    filter_set.stringify_keys!

    filter_set.select { |key, value| value.present? }.each do |key, value|
      rel = rel.where(kind: value) if key == "kinds"
      rel = rel.where("id ILIKE ANY (ARRAY[?])", value.map { |id| "#{id}%" }) if key == "ids"
      rel = rel.where("pubkey ILIKE ANY (ARRAY[?])", value.map { |author| "#{author}%" }) if key == "authors"

      if key == "#e"
        rel = rel.where("EXISTS (
          SELECT 1
          FROM jsonb_array_elements(tags) AS arr
          WHERE arr->>0 = 'e' AND (arr->>1 ILIKE ANY (ARRAY[?]))
        )", value.map { |t| "#{t}%" })
      end
      if key == "#p"
        rel = rel.where("EXISTS (
          SELECT 1
          FROM jsonb_array_elements(tags) AS arr
          WHERE arr->>0 = 'p' AND (arr->>1 ILIKE ANY (ARRAY[?]))
        )", value.map { |t| "#{t}%" })
      end

      rel = rel.where("created_at >= ?", Time.at(value)) if key == "since"
      rel = rel.where("created_at <= ?", Time.at(value)) if key == "until"
    end

    filter_limit = if filter_set["limit"].to_i > 0
      [filter_set["limit"].to_i, MAX_FILTER_LIMIT.to_i].min
    else
      DEFAULT_FILTER_LIMIT
    end

    rel.limit(filter_limit)
  end

  def matches_nostr_filter_set?(filter_set)
    filter_set.slice(*AVAILABLE_FILTERS).all? do |filter_type, filter_value|
      case filter_type
      when "kinds"
        kind.in?(filter_value)
      when "ids"
        filter_value.any? { |prefix| id.starts_with?(prefix) }
      when "authors"
        filter_value.any? { |prefix| pubkey.starts_with?(prefix) }
      when "#e"
        filter_value.any? do |prefix|
          tags.any? do |t|
            t[0] == "e" && t[1].starts_with?(prefix)
          end
        end
      when "#p"
        filter_value.any? do |prefix|
          tags.any? do |t|
            t[0] == "p" && t[1].starts_with?(prefix)
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
      content:,
      created_at: created_at.to_i,
      id:,
      kind:,
      pubkey:,
      sig:,
      tags:
    }
  end

  private

  def tags_must_be_array
    errors.add(:tags, "must be an array") unless tags.is_a?(Array)
  end

  def id_must_match_payload
    errors.add(:id, "must match payload") unless Digest::SHA256.hexdigest(JSON.dump(to_nostr_serialized)) === id
  end

  def sig_must_match_payload
    schnorr_params = [
      [id].pack("H*"),
      [pubkey].pack("H*"),
      [sig].pack("H*")
    ]

    errors.add(:sig, "must match payload") unless Schnorr.valid_sig?(*schnorr_params)
  end
end
