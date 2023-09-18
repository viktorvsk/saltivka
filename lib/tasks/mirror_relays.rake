namespace :relays do
  namespace :mirror do
    desc "Mirror all new events"
    task new: :environment do
      mirrors = RelayMirror.where(active: true, mirror_type: :future).pluck(:url)
      websockets = []

      EM.run do
        mirrors.each do |relay_url|
          ws = RelayMirrorClient.sync_future_events(relay_url)
          websockets << ws if ws
        end

        EM.add_periodic_timer(5) do
          new_mirrors = RelayMirror.where(active: true, mirror_type: :future).pluck(:url)

          if new_mirrors.sort != mirrors.sort
            websockets.each { |ws| ws.close }
            websockets = new_mirrors.map do |relay_url|
              RelayMirrorClient.sync_future_events(relay_url)
            end
            mirrors = new_mirrors
          end
        end
      end
    end

    desc "Mirror old events"
    task old: :environment do
      mirrors = RelayMirror.where(active: true, mirror_type: :past)
      websockets = []

      EM.run do
        mirrors.each do |mirror|
          ws = RelayMirrorClient.sync_past_events(relay_url: mirror.url, oldest: mirror.oldest, newest: mirror.newest)
          websockets << ws if ws
        end

        EM.add_periodic_timer(5) do
          new_mirrors = RelayMirror.where(active: true, mirror_type: :past)

          if mirrors.pluck(:url).sort != new_mirrors.pluck(:url).sort
            websockets.each { |ws| ws.close }
            websockets = new_mirrors.map do |mirror|
              RelayMirrorClient.sync_past_events(relay_url: mirror.url, oldest: mirror.oldest, newest: mirror.newest)
            end
            mirrors = new_mirrors
          end
        end
      end
    end
  end
end
