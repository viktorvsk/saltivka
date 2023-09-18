class SubscriptionMatcherQueryBuilder
  REDIS_SEARCH_SPECIAL_CHARACTERS = %w[\ /, . < > { } [ ] " ' : ; ! @ # $ % ^ & * ( ) - + = ~].map { |c| "\\#{c}" }.concat([" "])
  attr_reader :query

  def initialize(event)
    authors = [
      event.pubkey,
      event.delegation_tag_pubkey,
      SubscriptionQueryBuilder::REDIS_SEARCH_TAG_ANY_VALUE
    ].reject(&:blank?).join(" | ")

    @query = {
      "@kinds" => "{#{event.kind} | #{SubscriptionQueryBuilder::REDIS_SEARCH_TAG_ANY_VALUE}}",
      "@authors" => "{#{authors}}",
      "@ids" => "{#{event.sha256} | #{SubscriptionQueryBuilder::REDIS_SEARCH_TAG_ANY_VALUE}}"
    }.to_a.map { |f| %[(#{f.join(":")})] }

    query << "(@until:[0 0] | @until:[#{event.created_at.to_i} +inf])"
    query << "(@since:[0 0] | @since:[-inf #{event.created_at.to_i}])"

    SubscriptionQueryBuilder::SINGLE_LETTER_TAGS.each do |tag_name|
      event_tag_values = event.single_letter_tags
        .select { |t| t[0] == tag_name }.map(&:last).map { |v| v.present? ? v.gsub(/([#{REDIS_SEARCH_SPECIAL_CHARACTERS.join}])/, '\\\\\1') : SubscriptionQueryBuilder::REDIS_SEARCH_TAG_EMPTY_VALUE }
      values_with_any = [event_tag_values, SubscriptionQueryBuilder::REDIS_SEARCH_TAG_ANY_VALUE].flatten.join(" | ")
      query << "(@#{tag_name}:{#{values_with_any}})"
    end

    @query = query.sort.join(" ")
  end
end
