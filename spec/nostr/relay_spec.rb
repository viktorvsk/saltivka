require "rails_helper"

RSpec.describe "Nostr::Relay" do
  it "handles websocket request" do
    allow(SecureRandom).to receive(:hex).and_return("CONN_ID")

    ws_double = instance_double(Faye::WebSocket)

    expect(ws_double).to receive(:rack_response)
    expect(ws_double).to receive(:on).with(:open)
    expect(ws_double).to receive(:on).with(:message)
    expect(ws_double).to receive(:on).with(:close)
    expect(Faye::WebSocket).to receive(:new).and_return(ws_double)

    Nostr::Relay.call({
      "HTTP_CONNECTION" => "upgrade",
      "HTTP_UPGRADE" => "websocket",
      "REQUEST_METHOD" => "GET"
    })
  end

  describe "NIP-65" do
    context "with RELAY_CONFIG.forced_min_auth_level = 1" do
      it "doesn't process 10002 events" do
        # TODO: this should rather be a e2e test
      end
    end
  end
end
