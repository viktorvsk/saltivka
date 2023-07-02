class RelayConfig
  def default_format
    # TODO: another option is JSON [WIP]
    ENV.fetch("DEFAULT_ERRORS_FORMAT", "TEXT")
  end

  def mailer_default_from
    ENV.fetch("MAILER_DEFAULT_FROM", "admin@nostr.localhost")
  end

  def default_filter_limit
    ENV.fetch("DEFAULT_FILTER_LIMIT", 100).to_i
  end

  def validate_id_on_server
    val = ENV.fetch("VALIDATE_ID_ON_SERVER", true)
    ActiveRecord::Type::Boolean.new.cast(val)
  end

  def validate_sig_on_server
    val = ENV.fetch("VALIDATE_SIG_ON_SERVER", true)
    ActiveRecord::Type::Boolean.new.cast(val)
  end

  def available_filters
    nip_1_default_filters = "kinds ids authors #e #p since until"
    nip_12_tags = "#a #b #c #d #f #g #h #i #j #k #l #m #n #o #q #r #s #t #u #v #w #x #y #z #A #B #C #D #E #F #G #H #I #J #K #L #M #N #O #P #Q #R #S #T #U #V #W #X #Y #Z"
    ENV.fetch("NIP_1_12_AVAILABLE_FILTERS", "#{nip_1_default_filters} #{nip_12_tags}").to_s.split(" ")
  end

  def max_limit
    ENV.fetch("NIP_11_MAX_FILTER_LIMIT", 1000).to_i
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
    ENV.fetch("NIP_11_relay_countries", "UK UA US").to_s.split(" ")
  end

  def language_tags
    ENV.fetch("NIP_11_language_tags", "en en-419").to_s.split(" ")
  end

  def tags
    ENV.fetch("NIP_11_tags", "").to_s.split(" ")
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

  def max_searchable_tag_value_length
    ENV.fetch("NIP_12_max_searchable_tag_value_length", 1000).to_i
  end

  def min_pow
    ENV.fetch("NIP_13_MIN_POW", 0).to_i
  end

  def created_at_in_past
    ENV.fetch("NIP_22_CREATED_AT_IN_PAST", 1.year.to_i).to_i
  end

  def created_at_in_future
    ENV.fetch("NIP_22_CREATED_AT_IN_FUTURE", 3.months.to_i).to_i
  end

  def restrict_change_auth_pubkey
    val = ENV.fetch("NIP_42_restrict_change_auth_pubkey", false)
    ActiveRecord::Type::Boolean.new.cast(val)
  end

  def challenge_window_seconds
    ENV.fetch("NIP_42_challenge_window_seconds", 600).to_i
  end

  def fast_auth_window_seconds
    ENV.fetch("NIP_43_fast_auth_window_seconds", 60).to_i
  end

  def self_url
    ENV.fetch("NIP_42_43_SELF_URL", "ws://localhost:3000")
  end
end
