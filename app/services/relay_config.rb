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
end
