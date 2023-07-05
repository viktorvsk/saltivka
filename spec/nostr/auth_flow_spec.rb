require "rails_helper"

RSpec.describe Nostr::AuthenticationFlow do
  it "handles invalid JSON" do
    subject.call(ws_url: "ws://localhost?authorization=INVALID", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
      expect(message).to eq ["TERMINATE", "NIP-43 auth event has errors in JSON: unexpected token at 'INVALID'"]
    end
  end

  it "Falls back to NIP-42 if authorization param is not present" do
    subject.call(ws_url: "ws://localhost?authorization=", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
      expect(message).to eq ["AUTH", "CONN_ID"]
    end
  end

  context "with force_min_auth_level = 4" do
    it "creates Sidekiq job" do
    end

    it "waits for authorization result in a synchronous manner" do
    end

    it "termniates websocket connection" do
    end
  end
end
