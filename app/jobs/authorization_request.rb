class AuthorizationRequest
  include Sidekiq::Worker
  sidekiq_options queue: "nostr"

  # TODO: consider update active connections based on results
  def perform(connection_id, event_sha256, pubkey)
    if TrustedAuthor.joins(:author).where(authors: {pubkey: pubkey}).exists?
      MemStore.authorize!(cid: connection_id, level: "4")

      # It seems it makes sense to notify client AUTH is succesful, but NIP-16/NIP-20 tell us not to fanout ephemeral events
      # MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event_sha256, true, ""].to_json)
    # elsif assign level 3 if user has paid subscription
    # elsif assign level 2 if user is registered
    # elsif assign level -1 if user is banned
    else
      # assign level 1 if user is a guest but with authenticated public key
      MemStore.fanout(cid: connection_id, command: :ok, payload: ["OK", event_sha256, false, "restricted: unknown author"].to_json)
      MemStore.authorize!(cid: connection_id, level: "1")
    end
  end
end
