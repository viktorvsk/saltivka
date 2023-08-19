class SubscriptionMatcherQueryBuilder
  REDIS_SEARCH_SPECIAL_CHARACTERS = %w[, . < > { } [ ] " ' : ; ! @ # $ % ^ & * ( ) - + = ~].map { |c| "\\#{c}" }.concat([" "])
  attr_reader :query

  def initialize(event)
    tags = [
      event.nip12_tags.map { |t| t.join("_").gsub(/([#{REDIS_SEARCH_SPECIAL_CHARACTERS.join}])/, '\\\\\1') },
      SubscriptionQueryBuilder::REDIS_SEARCH_TAG_ANY_VALUE
    ].reject(&:blank?).join(" | ")

    authors = [
      event.pubkey,
      event.delegation_tag_pubkey,
      SubscriptionQueryBuilder::REDIS_SEARCH_TAG_ANY_VALUE
    ].reject(&:blank?).join(" | ")

    @query = {
      "@kinds" => "{#{event.kind} | #{SubscriptionQueryBuilder::REDIS_SEARCH_TAG_ANY_VALUE}}",
      "@authors" => "{#{authors}}",
      "@ids" => "{#{event.sha256} | #{SubscriptionQueryBuilder::REDIS_SEARCH_TAG_ANY_VALUE}}",
      "@tags" => "{#{tags}}"

    }.to_a.map { |f| %[(#{f.join(":")})] }

    query << "(@until:[0 0] | @until:[#{event.created_at.to_i} +inf])"
    query << "(@since:[0 0] | @since:[-inf #{event.created_at.to_i}])"
    @query = query.join(" ")
  end
end
