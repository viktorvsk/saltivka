require "test_helper"

class Nostr::AuthenticationFlowTest < ActiveSupport::TestCase
  test "handles invalid JSON" do
    Nostr::AuthenticationFlow.call("ws://localhost?authorization=INVALID", "CONN_ID") do |message|
      assert_equal message, ["NOTICE", "error: unexpected token at 'INVALID'"].to_json
    end
  end

  test "Falls back to NIP-42 if authorization param is not present" do
    Nostr::AuthenticationFlow.call("ws://localhost?authorization=", "CONN_ID") do |message|
      assert_equal message, ["AUTH", "CONN_ID"].to_json
    end
  end
end
