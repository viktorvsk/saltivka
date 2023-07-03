require "rails_helper"

RSpec.describe Nostr::AuthenticationFlow do
  it "handles invalid JSON" do
    Nostr::AuthenticationFlow.call(ws_url: "ws://localhost?authorization=INVALID", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
      expect(message).to eq ["NOTICE", "error: unexpected token at 'INVALID'"].to_json
    end
  end

  it "Falls back to NIP-42 if authorization param is not present" do
    Nostr::AuthenticationFlow.call(ws_url: "ws://localhost?authorization=", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
      expect(message).to eq ["AUTH", "CONN_ID"].to_json
    end
  end
end
