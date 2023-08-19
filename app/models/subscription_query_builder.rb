class SubscriptionQueryBuilder
  SINGLE_LETTER_TAGS = ("a".."z").to_a.concat(("A".."Z").to_a).map { |single_letter_tag| single_letter_tag }
  AVAILABLE_FILTERS = ["authors", "kinds", "ids", "since", "until"].concat(SINGLE_LETTER_TAGS)
  REDIS_SEARCH_TAG_ANY_VALUE = "__ANY__"
  REDIS_SEARCH_NUMERIC_ANY_VALUE = 0

  attr_reader :filter_set, :query

  def initialize(filter_set)
    filter_set.stringify_keys!
    @filter_set = filter_set.stringify_keys
    @query = filter_set.slice(*AVAILABLE_FILTERS)
    query["kinds"] = Array.wrap(filter_set["kinds"]).map(&:to_s)
    filter_set.select { |k, v| k =~ /\A#[a-zA-Z]\Z/ }.each do |k, v|
      query[k[1]] = v
    end

    AVAILABLE_FILTERS.each do |k|
      next if query[k].present?
      case k
      when "authors", "ids", "kinds", "tags"
        query[k] = [REDIS_SEARCH_TAG_ANY_VALUE]
      when "since"
        query[k] = REDIS_SEARCH_NUMERIC_ANY_VALUE
      when "until"
        query[k] = REDIS_SEARCH_NUMERIC_ANY_VALUE
      when /\A[a-zA-Z]\Z/
        query[k] = [REDIS_SEARCH_TAG_ANY_VALUE]
      end
    end

    @query = query.sort.to_h.to_json
  end
end
