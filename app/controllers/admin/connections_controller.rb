class Admin::ConnectionsController < AdminController
  def index
    @connections = ConnectionsViewer.new.call
  end

  def destroy
    MemStore.fanout(cid: params[:id], command: :terminate, payload: [3502, "restricted: connection was closed by the server"].to_json)

    redirect_to admin_connections_path
  end
end
