class AuthorizationRequest
  include Sidekiq::Worker
  sidekiq_options queue: "nostr"

  # TODO: consider update active connections based on data changes
  # i.e. when TrustedAuthor record is created check if there are
  # existing connections with this pubkey and update their auth_level
  # and do the opposite if TrustedAuthor record was deleted
  # NOTE: it seems it makes sense to notify client AUTH is succesful, but NIP-16/NIP-20 tell us not to fanout ephemeral events
  # MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event_sha256, true, ""].to_json)
  def perform(connection_id, event_sha256, pubkey)
    if TrustedAuthor.joins(:author).where(authors: {pubkey: pubkey}).exists?
      MemStore.authorize!(cid: connection_id, level: "4")
    elsif AuthorSubscription.active.joins(:author).where(authors: {pubkey: pubkey}).exists?
      MemStore.authorize!(cid: connection_id, level: "3")

    elsif User.active.joins(:authors).where(authors: {pubkey: pubkey}).where("users.id IN (#{User.active.select(:id).joins(authors: :author_subscription).where("author_subscriptions.expires_at > ?", Time.current).to_sql})").exists? # TODO: finish
      MemStore.authorize!(cid: connection_id, level: "3")
    elsif User.active.joins(:authors).where(authors: {pubkey: pubkey}).exists?
      MemStore.authorize!(cid: connection_id, level: "2")
    else
      # assign level 1 if user is a guest but with authenticated public key
      MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event_sha256, false, "restricted: unknown author"].to_json)
      MemStore.authorize!(cid: connection_id, level: "1")
    end
  end
end
