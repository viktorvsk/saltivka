class Admin::ConnectionsController < AdminController
  def index
    @connections = ConnectionsViewer.new.call
  end

  def destroy
    subscribers_count = MemStore.fanout(cid: params[:id], command: :terminate, payload: [3502, "restricted: connection was closed by the server"].to_json)

    if subscribers_count.zero?
      # It means that client was already disconnected and resource cleanup wasn't handled correctly
      MemStore.with_redis { |redis| Nostr::RelayController.new(connection_id: params[:id], rate_limited: false).terminate(event: nil, redis: redis) }
    end

    redirect_to admin_connections_path
  end
end
