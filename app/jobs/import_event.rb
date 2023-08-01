class ImportEvent
  include Sidekiq::Worker
  sidekiq_options queue: "nostr.import-event"

  def perform(connection_id, event_json)
    NewEvent.perform_sync(connection_id, event_json)
  end
end
