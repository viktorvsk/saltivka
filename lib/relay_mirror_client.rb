class RelayMirrorClient
  def self.sync_future_events(relay_url)
    ws = Faye::WebSocket::Client.new(relay_url)

    ws.on :open do |event|
      Rails.logger.info "\nConnected to #{relay_url}!\n"
      RelayMirror.where(url: relay_url, mirror_type: :future).update_all(session_started_at: Time.current)
      ws.send(["REQ", "MIRROR_SYNC_FUTURE", {limit: 0}].to_json)
    end

    ws.on :message do |event|
      message = JSON.parse(event.data)
      command = message.first

      case command.upcase
      when "EVENT"
        Sidekiq.redis { |c| c.call("PFADD", "hll.mirror.future.#{relay_url}", message.last["id"]) }

        if Sidekiq.redis { |c| c.call("BF.ADD", "seen-events", message.last["id"]) }
          ImportEvent.perform_async("INTERNAL", message.last.to_json)
          Rails.logger.debug("+")
        else
          Rails.logger.debug("duplicate")
        end
      end
    end

    ws.on :close do |event|
      Rails.logger.info "\n#{relay_url} closed connection with code=#{event.code}, reason=#{event.reason}\n"

      if event.code == 4000
        RelayMirror.where(url: relay_url, mirror_type: :future).update_all(active: false)
        Sidekiq.redis { |c| c.del("hll.mirror.future.#{relay_url}") }
      elsif event.code == 1000 || event.code == 1006
        Rails.logger.debug("Stop syncing #{relay_url}")
        Sidekiq.redis { |c| c.del("hll.mirror.future.#{relay_url}") }
      else
        EM.add_timer(1) do
          Rails.logger.info "Reconnecting to #{relay_url}..."
          sync_future_events(relay_url)
        end
      end
    end

    ws
  end

  def self.sync_past_events(relay_url:, oldest:, newest:)
    ws = Faye::WebSocket::Client.new(relay_url)
    newest ||= Time.now.to_i

    ws.on :open do |event|
      Rails.logger.info "\nConnected to #{relay_url}!\n"
      RelayMirror.where(url: relay_url, mirror_type: :past).update_all(session_started_at: Time.current)
      ws.send(["REQ", "MIRROR_SYNC_PAST_SINCE_#{oldest}_UNTIL_#{newest}", {limit: 100, until: newest}].to_json)
    end

    ws.on :message do |event|
      message = JSON.parse(event.data)
      command = message.first

      case command.upcase
      when "EOSE"
        sleep(1)
        ws.send(["CLOSE", message.last].to_json)

        if newest.to_i.positive? && oldest.to_i.positive? && newest.to_i <= oldest.to_i
          RelayMirror.where(url: relay_url, mirror_type: :past).update_all(active: false, newest: newest)
        elsif newest
          ws.send(["REQ", "MIRROR_SYNC_PAST_SINCE_#{oldest}_UNTIL_#{newest}", {limit: 100, until: newest}].to_json)
        end
      when "EVENT"
        newest = [message.last["created_at"].to_i, newest.to_i].min
        Sidekiq.redis { |c| c.call("PFADD", "hll.mirror.past.#{relay_url}", message.last["id"]) }

        if Sidekiq.redis { |c| c.call("BF.ADD", "seen-events", message.last["id"]) }
          ImportEvent.perform_async("INTERNAL", message.last.to_json)
          Rails.logger.debug("+")
        else
          Rails.logger.debug("duplicate")
        end
      end
    end

    ws.on :close do |event|
      Rails.logger.info "\n#{relay_url} closed connection with code=#{event.code}, reason=#{event.reason}\n"

      if event.code == 4000
        Rails.logger.debug("Stop syncing #{relay_url} because relay doesn't want us to")
        RelayMirror.where(url: relay_url, mirror_type: :past).update_all(active: false, newest: newest)
        Sidekiq.redis { |c| c.del("hll.mirror.past.#{relay_url}") }
      elsif event.code == 1000 || event.code == 1006
        RelayMirror.where(url: relay_url, mirror_type: :past).update_all(newest: newest)
        Rails.logger.debug("Stop syncing #{relay_url} because settings changed")
        Sidekiq.redis { |c| c.del("hll.mirror.past.#{relay_url}") }
      else
        EM.add_timer(1) do
          Rails.logger.info "Reconnecting to #{relay_url}..."
          sync_past_events(relay_url: relay_url, oldest: oldest, newest: newest)
        end
      end
    end

    ws
  end
end
