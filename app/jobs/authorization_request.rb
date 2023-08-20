class AuthorizationRequest
  include Sidekiq::Worker
  sidekiq_options queue: "nostr.nip42"

  # TODO: consider update active connections based on data changes
  # i.e. when TrustedAuthor record is created check if there are
  # existing connections with this pubkey and update their auth_level
  # and do the opposite if TrustedAuthor record was deleted
  def perform(cid, event_sha256, pubkey)
    if TrustedAuthor.joins(:author).where("LOWER(authors.pubkey) = ?", pubkey.downcase).exists?
      MemStore.authorize!(cid: cid, level: "4")
      ok(cid, event_sha256)
    elsif AuthorSubscription.active.joins(:author).where("LOWER(authors.pubkey) = ?", pubkey.downcase).exists?
      MemStore.authorize!(cid: cid, level: "3")
      ok(cid, event_sha256)
    elsif User.active.joins(:authors).where("LOWER(authors.pubkey) = ?", pubkey.downcase).where("users.id IN (#{User.active.select(:id).joins(authors: :author_subscription).where("author_subscriptions.expires_at > ?", Time.current).to_sql})").exists? # TODO: finish
      MemStore.authorize!(cid: cid, level: "3")
      ok(cid, event_sha256)
    elsif User.active.joins(:authors).where("LOWER(authors.pubkey) = ?", pubkey.downcase).exists?
      MemStore.authorize!(cid: cid, level: "2")
      ok(cid, event_sha256)
    else
      # assign level 1 if user is a guest but with authenticated public key
      MemStore.fanout(cid: cid, command: :ok, payload: ["OK", event_sha256, false, "restricted: unknown author"].to_json)
      MemStore.authorize!(cid: cid, level: "1")
    end
  end

  private

  def ok(cid, event_sha256)
    MemStore.fanout(cid: cid, command: :ok, payload: ["OK", event_sha256, true, ""].to_json)
  end
end
