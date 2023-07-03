class NewEvent
  include Sidekiq::Worker
  sidekiq_options queue: "nostr"

  def perform(connection_id, event_json)
    event_params = JSON.parse(event_json)
    event_params["created_at"] = Time.at(event_params["created_at"])
    event_params["sha256"] = event_params.delete("id")

    event = Event.new(event_params)
    should_fanout_without_save = event.kinda?(:ephemeral) && event.valid?

    if should_fanout_without_save || event.save

      if event.kinda?(:private)
        if event.kind === 22242 # NIP-42
          if RELAY_CONFIG.restrict_change_auth_pubkey && MemStore.pubkey?(cid: connection_id)
            MemStore.fanout(cid: connection_id, command: :notice, payload: "This connection is already authenticated. To authenticate another pubkey please open new connection")
          else
            MemStore.auth!(cid: connection_id, pubkey: event.pubkey)
          end
        end
      else
        # TODO: This should be a LUA script
        MemStore.subscriptions.each do |pubsub_id, filters|
          matches = JSON.parse(filters).any? { |filter_set| event.matches_nostr_filter_set?(filter_set) }
          next unless matches
          subscriber_cid, subscriber_sid = pubsub_id.split(":")
          if event.kind === 4
            event_p_tag = event.tags.find { |t| t.first == "p" }
            next unless event_p_tag.present? # TODO: process invalid kind 4 event
            subscriber_pubkey = MemStore.pubkey_for(cid: subscriber_cid)
            # We don't have to send this event to author because only subscriptions
            # with matching filters should receive it
            # We also don't have to do anything regarding delegation because
            # delegation is only about publishing events and not receiving
            next if event_p_tag.second != subscriber_pubkey

          end
          MemStore.fanout(cid: subscriber_cid, sid: subscriber_sid, command: :found_event, payload: event.to_json)
        end

        MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event.sha256, true, ""].to_json) unless event.kinda?(:ephemeral) # NIP-16/NIP-20
      end

    elsif event.errors[:sha256].include?("has already been taken") || event.errors[:sig].include?("has already been taken")
      MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event.sha256, false, "duplicate: this event is already present in the database"].to_json)
    elsif event.errors[:sha256].any? { |error_text| error_text.to_s =~ /PoW difficulty must be at least/ }
      MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event.sha256, false, "pow: min difficulty must be #{RELAY_CONFIG.min_pow}, got #{event.pow_difficulty}"].to_json)
    elsif event.errors[:"author.pubkey"].include?("has already been taken") || event.author.errors[:pubkey].include?("has already been taken") # TODO: consider remove
      NewEvent.perform_async(connection_id, event_json)
      return event
    else
      MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event.sha256, false, "error: #{event.errors.full_messages.join(", ")}"].to_json) # TODO: errors presenter
    end

    event
  rescue ActiveRecord::RecordNotUnique => _e
    MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event.sha256, false, "duplicate: this event is already present in the database"].to_json)
  end
end
