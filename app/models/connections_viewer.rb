class ConnectionsViewer
  def call
    connections, connections_authenticators, authentications, authorizations, requests, incoming_traffic, outgoing_traffic, ips, starts = Sidekiq.redis do |c|
      c.multi do |t|
        t.smembers("connections")
        t.hgetall("connections_authenticators")
        t.hgetall("authentications")
        t.hgetall("authorizations")
        t.hgetall("requests")
        t.hgetall("incoming_traffic")
        t.hgetall("outgoing_traffic")
        t.hgetall("connections_ips")
        t.hgetall("connections_starts")
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
        subscriptions: subscriptions[index],
        requests: requests[cid],
        incoming_traffic: incoming_traffic[cid],
        outgoing_traffic: outgoing_traffic[cid],
        ip: ips[cid],
        starts: starts[cid]
      }
    end
  end
end
