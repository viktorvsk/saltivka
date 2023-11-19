class RelayConfig
  DYNAMIC_CONFIGURATION = %w[maintenance max_allowed_connections unlimited_ips]

  def default_invoice_amount
    ENV.fetch("DEFAULT_INVOICE_AMOUNT", 6000).to_i
  end

  def default_invoice_period
    ENV.fetch("DEFAULT_INVOICE_PERIOD", 30).to_i
  end

  def price_per_day
    ENV.fetch("PRICE_PER_DAY", 200).to_i
  end

  def invoice_ttl
    ENV.fetch("INVOICE_TTL", 1200).to_i
  end

  def heartbeat_interval
    ENV.fetch("HEARBEAT_INTERVAL", 1200).to_i
  end

  def rate_limiting_sliding_window
    ENV.fetch("RATE_LIMITING_SLIDING_WINDOW", 60).to_i
  end

  def rate_limiting_max_requests
    ENV.fetch("RATE_LIMITING_MAX_REQUESTS", 300).to_i
  end

  def authorization_timeout
    ENV.fetch("AUTHORIZATION_TIMEOUT", 10).to_i
  end

  def forced_min_auth_level
    ENV.fetch("FORCED_MIN_AUTH_LEVEL", 0).to_i
  end

  def required_auth_level_for_req
    ENV.fetch("REQUIRED_AUTH_LEVEL_FOR_REQ", 0).to_i
  end

  def required_auth_level_for_close
    # Its not a typo that the same env variable is used
    # close command should have the same auth level as req
    # Some edge cases possible if auth level was changed between calls
    ENV.fetch("REQUIRED_AUTH_LEVEL_FOR_REQ", 0).to_i
  end

  def required_auth_level_for_event
    ENV.fetch("REQUIRED_AUTH_LEVEL_FOR_EVENT", 0).to_i
  end

  def required_auth_level_for_count
    ENV.fetch("REQUIRED_AUTH_LEVEL_FOR_COUNT", 0).to_i
  end

  def default_filter_limit
    ENV.fetch("DEFAULT_FILTER_LIMIT", 100).to_i
  end

  def enforce_kind_4_authentication
    val = ENV.fetch("NIP_04_NIP_42_ENFORCE_KIND_4_AUTHENTICATION", true)
    ActiveRecord::Type::Boolean.new.cast(val)
  end

  def max_limit
    ENV.fetch("NIP_11_MAX_FILTER_LIMIT", 1000).to_i
  end

  def relay_name
    ENV.fetch("NIP_11_RELAY_NAME", "")
  end

  def description
    ENV.fetch("NIP_11_DESCRIPTION", "")
  end

  def pubkey
    ENV.fetch("NIP_11_PUBKEY", "")
  end

  def contact
    ENV.fetch("NIP_11_CONTACT", "")
  end

  def relay_countries
    ENV.fetch("NIP_11_RELAY_COUNTRIES", "UK UA US").to_s.split(" ")
  end

  def language_tags
    ENV.fetch("NIP_11_LANGUAGE_TAGS", "en en-419").to_s.split(" ")
  end

  def tags
    ENV.fetch("NIP_11_TAGS", "").to_s.split(" ")
  end

  def posting_policy_url
    ENV.fetch("NIP_11_POSTING_POLICY", "")
  end

  def max_subscriptions
    ENV.fetch("NIP_11_MAX_SUBSCRIPTIONS", 20).to_i
  end

  def max_message_length
    ENV.fetch("NIP_11_MAX_MESSAGE_LENGTH", 16384).to_i
  end

  def max_searchable_tag_value_length
    ENV.fetch("NIP_12_MAX_SEARCHABLE_TAG_VALUE_LENGTH", 1000).to_i
  end

  def min_pow
    ENV.fetch("NIP_13_MIN_POW", 0).to_i
  end

  def restrict_change_auth_pubkey
    val = ENV.fetch("NIP_42_RESTRICT_CHANGE_AUTH_PUBKEY", false)
    ActiveRecord::Type::Boolean.new.cast(val)
  end

  def challenge_window_seconds
    ENV.fetch("NIP_42_CHALLENGE_WINDOW_SECONDS", 600).to_i
  end

  def fast_auth_window_seconds
    ENV.fetch("NIP_43_FAST_AUTH_WINDOW_SECONDS", 60).to_i
  end

  def self_url
    ENV.fetch("NIP_42_43_SELF_URL", "ws://localhost:3000")
  end

  def count_cost_threshold
    ENV.fetch("NIP_45_COUNT_COST_THRESHOLD", 0).to_i
  end

  def content_searchable_kinds
    ENV.fetch("NIP_50_CONTENT_SEARCHABLE_KINDS", "1 30023").split(" ").map(&:to_i)
  end

  def kinds_exempt_of_auth
    ENV.fetch("NIP_65_KINDS_EXEMPT_OF_AUTH", "10002").to_s.split(" ").map(&:to_i)
  end

  # Are static but may be changed

  def default_format
    # TODO: another option is JSON [WIP]
    ENV.fetch("DEFAULT_ERRORS_FORMAT", "TEXT")
  end

  def validate_id_on_server
    val = ENV.fetch("VALIDATE_ID_ON_SERVER", true)
    ActiveRecord::Type::Boolean.new.cast(val)
  end

  def validate_sig_on_server
    val = ENV.fetch("VALIDATE_SIG_ON_SERVER", true)
    ActiveRecord::Type::Boolean.new.cast(val)
  end

  def max_content_length
    ENV.fetch("NIP_11_MAX_CONTENT_LENGTH", 8196).to_i
  end

  def provider_api_key_open_node
    ENV["PROVIDER_API_KEY_OPEN_NODE"]
  end

  def ts_default_language
    ENV.fetch("NIP_50_DEFAULT_LANGUAGE", "english")
  end

  def max_filters
    ENV.fetch("NIP_11_MAX_FILTERS", 100).to_i
  end

  def max_event_tags
    ENV.fetch("NIP_11_MAX_EVENT_TAGS", 100).to_i
  end

  # Must be static

  def ws_deflate_enabled
    val = ENV.fetch("WS_DEFLATE_ENABLED", "true")
    ActiveRecord::Type::Boolean.new.cast(val)
  end

  def ws_deflate_level
    ENV.fetch("WS_DEFLATE_LEVEL", "9").to_i
  end

  def ws_deflate_max_window_bits
    ENV.fetch("WS_DEFLATE_MAX_WINDOW_BITS", "15").to_i
  end

  def mailer_default_from
    ENV.fetch("MAILER_DEFAULT_FROM", "admin@nostr.localhost")
  end

  def supported_nips
    nips = Set.new(%w[1 2 5 9 11 13 15 26 28 40 42 43 45 50])
    nips.add(4) if enforce_kind_4_authentication
    nips.add(65) if kinds_exempt_of_auth.include?(10002)

    nips.map(&:to_i).sort
  end

  def software
    "https://github.com/viktorvsk/saltivka"
  end

  def version
    ENV["GIT_COMMIT"]
  end
end
