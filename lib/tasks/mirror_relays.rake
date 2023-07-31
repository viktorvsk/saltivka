def sync_future_events(relay_url)
  ws = Faye::WebSocket::Client.new(relay_url)

  ws.on :open do |event|
    Rails.logger.info "\nConnected to #{relay_url}!\n"
    ws.send(["REQ", "MIRROR_SYNC", {limit: 0}].to_json)
  end

  ws.on :message do |event|
    message = JSON.parse(event.data)
    command = message.first

    case command.upcase
    when "EVENT"
      if Sidekiq.redis { |c| c.call("BF.ADD", "seen-events", message.last["id"]) }
        NewEvent.perform_async("INTERNAL", message.last.to_json)
        Rails.logger.debug("+")
      else
        Rails.logger.debug("duplicate")
      end
    end
  end

  ws.on :close do |event|
    Rails.logger.info "\n#{relay_url} closed connection with code=#{event.code}, reason=#{event.reason}\n"

    if event.code == 4000
      RelayMirror.where(url: relay_url).update_all(active: false)
    elsif event.code == 1000
      Rails.logger.debug("Stop syncing #{relay_url}")
    else
      EM.add_timer(1) do
        Rails.logger.info "Reconnecting to #{relay_url}..."
        sync_future_events(relay_url)
      end
    end
  end

  ws
end

namespace :relays do
  namespace :mirror do
    desc "Mirror all new events"
    task new: :environment do
      mirrors = RelayMirror.where(active: true).pluck(:url)
      websockets = []

      EM.run do
        mirrors.each do |relay_url|
          websockets << sync_future_events(relay_url)
        end

        EM.add_periodic_timer(5) do
          new_mirrors = RelayMirror.where(active: true).pluck(:url)

          if new_mirrors.sort != mirrors.sort
            websockets.each { |ws| ws.close }
            websockets = new_mirrors.map do |relay_url|
              sync_future_events(relay_url)
            end
            mirrors = new_mirrors
          end
        end
      end
    end

    desc "Mirror old events"
    task old: :environment do
    end
  end
end
