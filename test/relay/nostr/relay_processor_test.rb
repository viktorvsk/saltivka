require "test_helper"

class Nostr::RelayProcessorTest < ActiveSupport::TestCase
  test "handles EOSE" do
    assert_equal ["EOSE", "subid"].to_json, Nostr::RelayProcessor.call("events:conn_id:subid:found_end", "EOSE")
  end

  test "handles OK" do
    event = create(:event)
    assert_equal ["OK", event].to_json, Nostr::RelayProcessor.call("events:conn_id:subid:ok", ["OK", event].to_json)
  end

  test "handles COUNT" do
    create(:event, kind: 123, content: "a")
    create(:event, kind: 123, content: "b")
    assert_equal ["COUNT", "subid", {count: 2}].to_json, Nostr::RelayProcessor.call("events:conn_id:subid:count", "2")
  end

  test "handles EVENT" do
    assert_equal ["EVENT", "SUBID", {id: "HEX"}].to_json, Nostr::RelayProcessor.call("events:CONN_ID:SUBID:found_event", {id: "HEX"}.to_json)
  end

  test "handles NOTICE" do
    assert_equal ["NOTICE", "message"].to_json, Nostr::RelayProcessor.call("events:CONN_ID:_:notice", "message")
  end
end
