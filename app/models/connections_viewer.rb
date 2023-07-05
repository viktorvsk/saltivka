class ConnectionsViewer
  def call
    connections, connections_authenticators, authentications, authorizations = Sidekiq.redis do |c|
      c.multi do |t|
        t.smembers("connections")
        t.hgetall("connections_authenticators")
        t.hgetall("authentications")
        t.hgetall("authorizations")
      end
    end
    subscriptions = Sidekiq.redis do |c|
      c.multi do |t|
        connections.each { |cid| t.smembers("client_reqs:#{cid}") }
      end
    end

    connections.each_with_index.map do |cid, index|
      {
        id: cid,
        auth_level: authorizations[cid].to_i,
        pubkey: authentications[cid],
        auth_event_22242: connections_authenticators[cid],
        subscriptions: subscriptions[index]
      }
    end
  end
end
