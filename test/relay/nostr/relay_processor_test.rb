require "test_helper"

class Nostr::RelayProcessorTest < ActiveSupport::TestCase
  test "handles EOSE" do
    ws_mock = Minitest::Mock.new
    ws_mock.expect(:send, nil, [["EOSE", "subid"].to_json])
    Nostr::RelayProcessor.new(ws: ws_mock).call("events:conn_id:subid:found_end", "EOSE")
    ws_mock.verify
  end

  test "handles OK" do
    event = create(:event)
    ws_mock = Minitest::Mock.new
    ws_mock.expect(:send, nil, [["OK", event].to_json])
    Nostr::RelayProcessor.new(ws: ws_mock).call("events:conn_id:subid:ok", ["OK", event].to_json)
    ws_mock.verify
  end

  test "handles COUNT" do
    create(:event, kind: 123, content: "a")
    create(:event, kind: 123, content: "b")
    ws_mock = Minitest::Mock.new
    ws_mock.expect(:send, nil, [["COUNT", "subid", {count: 2}].to_json])
    Nostr::RelayProcessor.new(ws: ws_mock).call("events:conn_id:subid:count", "2")
    ws_mock.verify
  end

  test "handles EVENT" do
    ws_mock = Minitest::Mock.new
    ws_mock.expect(:send, nil, [["EVENT", "SUBID", {id: "HEX"}].to_json])
    Nostr::RelayProcessor.new(ws: ws_mock).call("events:CONN_ID:SUBID:found_event", {id: "HEX"}.to_json)
    ws_mock.verify
  end

  test "handles NOTICE" do
    ws_mock = Minitest::Mock.new
    ws_mock.expect(:send, nil, [["NOTICE", "message"].to_json])
    Nostr::RelayProcessor.new(ws: ws_mock).call("events:CONN_ID:_:notice", "message")
    ws_mock.verify
  end

  test "handles TERMINATE" do
    ws_mock = Minitest::Mock.new
    ws_mock.expect(:close, nil, [403, "blocked"])
    Nostr::RelayProcessor.new(ws: ws_mock).call("events:CONN_ID:_:terminate", [403, "blocked"].to_json)
    ws_mock.verify
  end
end
