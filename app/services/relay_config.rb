class RelayConfig
  def max_filter_limit
    ENV.fetch("MAX_FILTER_LIMIT", 1000)
  end

  def default_filter_limit
    ENV.fetch("DEFAULT_FILTER_LIMIT", 100)
  end

  def available_filters
    %w[kinds ids authors #e #p since until]
  end

  def created_at_in_past
    ENV.fetch("CREATED_AT_IN_PAST", 1.year.to_i).to_i
  end

  def created_at_in_future
    ENV.fetch("CREATED_AT_IN_FUTURE", 3.months.to_i).to_i
  end
end
