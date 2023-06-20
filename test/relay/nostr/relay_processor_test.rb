require "test_helper"

class Nostr::RelayProcessorTest < ActiveSupport::TestCase
  setup do
    @subject = Nostr::RelayProcessor.new(proc {})
  end

  test "handles EOSE" do
    @subject.call("channel", "EOSE")
  end

  test "handles EVENT" do
    assert_equal ["EVENT", "SUBID", {id: "HEX"}].to_json, @subject.call("CONN_ID:SUBID", {id: "HEX"})
  end
end
