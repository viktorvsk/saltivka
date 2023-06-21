require "test_helper"

class Nostr::RelayProcessorTest < ActiveSupport::TestCase
  test "handles EOSE" do
    Nostr::RelayProcessor.call("events:conn_id:subid:found_end", "EOSE")
  end

  test "handles EVENT" do
    assert_equal ["EVENT", "SUBID", {id: "HEX"}].to_json, Nostr::RelayProcessor.call("events:CONN_ID:SUBID:found_event", {id: "HEX"}.to_json)
  end
end
