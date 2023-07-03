require "rails_helper"

RSpec.describe Nostr::RelayProcessor do
  it "handles EOSE" do
    ws_mock = instance_double(Faye::WebSocket)
    expect(ws_mock).to receive(:send).with(["EOSE", "subid"].to_json)
    Nostr::RelayProcessor.new(ws: ws_mock).call("events:conn_id:subid:found_end", "EOSE")
  end

  it "handles OK" do
    event = create(:event)
    ws_mock = instance_double(Faye::WebSocket)
    expect(ws_mock).to receive(:send).with(["OK", event].to_json)
    Nostr::RelayProcessor.new(ws: ws_mock).call("events:conn_id:subid:ok", ["OK", event].to_json)
  end

  it "handles COUNT" do
    create(:event, kind: 123, content: "a")
    create(:event, kind: 123, content: "b")
    ws_mock = instance_double(Faye::WebSocket)
    expect(ws_mock).to receive(:send).with(["COUNT", "subid", {count: 2}].to_json)
    Nostr::RelayProcessor.new(ws: ws_mock).call("events:conn_id:subid:count", "2")
  end

  it "handles EVENT" do
    ws_mock = instance_double(Faye::WebSocket)
    expect(ws_mock).to receive(:send).with(["EVENT", "SUBID", {id: "HEX"}].to_json)
    Nostr::RelayProcessor.new(ws: ws_mock).call("events:CONN_ID:SUBID:found_event", {id: "HEX"}.to_json)
  end

  it "handles NOTICE" do
    ws_mock = instance_double(Faye::WebSocket)
    expect(ws_mock).to receive(:send).with(["NOTICE", "message"].to_json)
    Nostr::RelayProcessor.new(ws: ws_mock).call("events:CONN_ID:_:notice", "message")
  end

  it "handles TERMINATE" do
    ws_mock = instance_double(Faye::WebSocket)
    expect(ws_mock).to receive(:close).with(403, "blocked")
    Nostr::RelayProcessor.new(ws: ws_mock).call("events:CONN_ID:_:terminate", [403, "blocked"].to_json)
  end
end
