class RelayConfig
  def max_limit
    ENV.fetch("MAX_FILTER_LIMIT", 1000)
  end

  def self_url
    ENV.fetch("SELF_URL", "ws://localhost:3000")
  end

  def challenge_window_seconds
    ENV.fetch("NIP_42_challenge_window_seconds", 600).to_i
  end

  def fast_auth_window_seconds
    ENV.fetch("NIP_43_fast_auth_window_seconds", 60).to_i
  end

  def default_filter_limit
    ENV.fetch("DEFAULT_FILTER_LIMIT", 100)
  end

  def available_filters
    # TODO: support capital letters for NIP-12
    ENV.fetch("AVAILABLE_FILTERS", "kinds ids authors #e #p since until #a #b #c #d #f #g #h #i #j #k #l #m #n #o #q #r #s #t #u #v #w #x #y #z").split(" ")
  end

  def created_at_in_past
    ENV.fetch("CREATED_AT_IN_PAST", 1.year.to_i).to_i
  end

  def created_at_in_future
    ENV.fetch("CREATED_AT_IN_FUTURE", 3.months.to_i).to_i
  end

  def min_pow
    ENV.fetch("MIN_POW", 0)
  end

  def relay_name
    ENV.fetch("NIP_11_relay_name", "")
  end

  def description
    ENV.fetch("NIP_11_description", "")
  end

  def pubkey
    ENV.fetch("NIP_11_pubkey", "")
  end

  def contact
    ENV.fetch("NIP_11_contact", "")
  end

  def supported_nips
    ENV.fetch("NIP_11_supported_nips", "")
  end

  def software
    ENV.fetch("NIP_11_software", "")
  end

  def version
    ENV.fetch("NIP_11_version", "")
  end

  def relay_countries
    ENV.fetch("NIP_11_relay_countries", "UK UA US")
  end

  def language_tags
    ENV.fetch("NIP_11_language_tags", "en en-419")
  end

  def tags
    ENV.fetch("NIP_11_tags", "")
  end

  def posting_policy_url
    ENV.fetch("NIP_11_posting_policy", "")
  end

  def max_subscriptions
    ENV.fetch("NIP_11_max_subscriptions", 20).to_i
  end

  def max_filters
    ENV.fetch("NIP_11_max_filters", 100).to_i
  end

  def min_prefix
    ENV.fetch("NIP_11_min_prefix", 4).to_i
  end

  def max_event_tags
    ENV.fetch("NIP_11_max_event_tags", 100).to_i
  end

  def max_content_length
    ENV.fetch("NIP_11_max_content_length", 8196).to_i
  end

  def max_message_length
    ENV.fetch("NIP_11_max_message_length", 16384).to_i
  end
end
