class NewEvent
  include Sidekiq::Worker
  sidekiq_options queue: "nostr.nip01.event"

  def perform(connection_id, event_json)
    event_params = JSON.parse(event_json)
    pubkey = event_params.delete("pubkey")
    author = Author.from_pubkey(pubkey)

    event_params.merge!({
      "created_at" => Time.at(event_params["created_at"]),
      "sha256" => event_params.delete("id"),
      "author" => author
    })

    event = begin
      Event.new(event_params)
    rescue => e
      Sentry.capture_exception(e)
      Sentry.capture_message("[NewEvent][#{e.class}] event_json=#{event_params}", level: :warning)
      return
    end
    should_fanout_without_save = event.kinda?(:ephemeral) && event.valid?

    if should_fanout_without_save || event.save

      if event.kinda?(:private)
        if event.kind === 22242 # NIP-42
          if RELAY_CONFIG.restrict_change_auth_pubkey && MemStore.pubkey?(cid: connection_id)
            MemStore.fanout(cid: connection_id, command: :notice, payload: "This connection is already authenticated. To authenticate another pubkey please open new connection")
          else
            MemStore.authenticate!(cid: connection_id, event_sha256: event.sha256, pubkey: event.pubkey)
          end
        end
      else
        MemStore.fanout_new_event_to_all_active_subscriptions(event)

        MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event.sha256, true, ""].to_json)
      end
    elsif event.errors[:sha256].include?("has already been taken")
      MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event.sha256, false, "duplicate: this event is already present in the database (for replaceable and parameterized replaceable events it may mean newer events are present)"].to_json)
    elsif event.errors[:sha256].any? { |error_text| error_text.to_s =~ /PoW difficulty must be at least/ }
      MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event.sha256, false, "pow: min difficulty must be #{RELAY_CONFIG.min_pow}, got #{event.pow_difficulty}"].to_json)
    else
      MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event.sha256, false, "error: #{Nostr::Presenters::Errors.new(event.errors.to_hash(full: true))}"].to_json)
    end

    if event.valid?
      MemStore.add_latest_event(event: event.to_json)
    else
      Sentry.capture_message("[NewEvent][InvalidEvent] event=#{event.to_json} errors=#{event.errors.to_a}", level: :warning)
    end

    event
  rescue ActiveRecord::RecordNotUnique => _e
    Sentry.capture_message("[NewEvent][DuplicateEvent] event=#{event.to_json}", level: :warning)
    MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event.sha256, false, "duplicate: this event is already present in the database (for replaceable and parameterized replaceable events it may mean newer events are present)"].to_json)
  end
end
