require "rails_helper"

RSpec.describe Nostr::Relay do
  it "sample non-websocket request" do
    # TODO: test actual values
    expect(Nostr::Relay.call({})).to eq [200, {"Content-Type" => "application/json"}, [Nostr::Nips::Nip11.call.to_json]]
  end

  it "websocket request" do
    allow(SecureRandom).to receive(:hex).and_return("CONN_ID")

    ws_double = instance_double(Faye::WebSocket)

    expect(ws_double).to receive(:rack_response)
    expect(ws_double).to receive(:send).with(["AUTH", "CONN_ID"].to_json)
    expect(ws_double).to receive(:on).with(:message)
    expect(ws_double).to receive(:on).with(:close)
    expect(ws_double).to receive(:url).and_return("ws://localhost:3000")
    expect(Faye::WebSocket).to receive(:new).and_return(ws_double)

    Nostr::Relay.call({
      "HTTP_CONNECTION" => "upgrade",
      "HTTP_UPGRADE" => "websocket",
      "REQUEST_METHOD" => "GET"
    })
  end
end
