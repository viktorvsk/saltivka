class Event < ApplicationRecord
  def self.by_nostr_filters(filter_set)
    rel = all.select(:id)

    filter_set.each do |key, value|
      rel = rel.where(kind: value) if key == "kinds"
      rel = rel.where("id ILIKE ANY (VALUES ?)", value.map { |id| "(#{id}%)" }) if key == "ids"
      rel = rel.where("pubkey ILIKE ANY (VALUES ?)", value.map { |author| "(#{author}%)" }) if key == "authors"

      if key == "#e"
        rel = rel.where("EXISTS (
          SELECT 1
          FROM jsonb_array_elements(tags) AS arr
          WHERE arr->>0 = 'e' AND (arr->>1 ILIKE ANY (VALUES ?))
        )", value.map { |t| "(#{t}%)" })
      end
      if key == "#p"
        rel = rel.where("EXISTS (
          SELECT 1
          FROM jsonb_array_elements(tags) AS arr
          WHERE arr->>0 = 'p' AND (arr->>1 ILIKE ANY (VALUES ?))
        )", value.map { |t| "(#{t}%)" })
      end

      rel = rel.where("created_at >= ?", value) if key == "since"
      rel = rel.where("created_at <= ?", value) if key == "until"
      rel = rel.limit(value.to_i) if key == "limit"
    end

    rel
  end

  def matches_nostr_filter_set?(filter_set)
    filter_set["kinds"].include?(event.kind) ||
      filter_set["ids"].any? { |prefix| event.id.starts_with?(prefix) } ||
      filter_set["authors"].any? { |prefix| event.pubkey.starts_with?(prefix) } ||
      filter_set["#e"].any? { |prefix| event.tags.any? { |t| t[0] == "e" && t[1].starts_with?(prefix) } } ||
      filter_set["#p"].any? { |prefix| event.tags.any? { |t| t[0] == "p" && t[1].starts_with?(prefix) } } ||
      event.created_at >= filter_set["since"] ||
      event.created_at <= filter_set["until"]
  end
end
