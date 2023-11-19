class DeleteExpiredEventNip40
  include Sidekiq::Worker
  sidekiq_options queue: "nostr.nip40"

  def perform(sha256)
    Event.includes(:searchable_content).where("LOWER(events.sha256) = ?", sha256).destroy_all
  end
end
