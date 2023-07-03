require "rails_helper"

RSpec.describe("NIP-43") do
  describe Nostr::AuthenticationFlow do
    context "with valid event of kind 22242" do
      it "authenticates connection pubkey" do
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 5.seconds.ago)
        payload = CGI.escape(event.to_json)

        Nostr::AuthenticationFlow.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION)

        expect(REDIS_TEST_CONNECTION.get("events22242:#{event.sha256}")).to eq("CONN_ID")
        expect(REDIS_TEST_CONNECTION.hget("authentications", "CONN_ID")).to eq(event.pubkey)
      end
    end

    context "with invalid data for event 22242" do
      it "responds with NOTICE" do
        event = build(:event, kind: 22242, created_at: 5.seconds.ago)
        payload = CGI.escape(event.to_json)

        Nostr::AuthenticationFlow.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
          expect(message).to eq(["NOTICE", "error: Tag 'relay' is missing"].to_json)
        end
      end
    end

    describe "validates 22242 event according to NIP-43" do
      it "validates the 22242 event" do
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
        expect(Nostr::Nips::Nip43.call(event.as_json.stringify_keys)).to eq([event.pubkey, []])
      end
    end

    it "terminates current connection if previous connection is active and auth-event key expired" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 61.seconds.ago)
      payload = CGI.escape(event.to_json)
      # Assumed state of Redis is like the following
      # REDIS_TEST_CONNECTION.hset("authentications", "FIRST_CONN_ID", event.pubkey)
      # REDIS_TEST_CONNECTION.del("events22242:#{event.sha256}")
      # But it doesn't actually make any difference
      # TODO: proper way to test it is using Timecop and time freeze

      Nostr::AuthenticationFlow.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
        expect(message).to eq(["NOTICE", "error: Created At is too old, expected window is 60 seconds"].to_json)
      end
    end

    it "terminates current connection if previous connection is not present and auth-event key not yet expired" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 5.seconds.ago)
      payload = CGI.escape(event.to_json)

      REDIS_TEST_CONNECTION.set("events22242:#{event.sha256}", "") # simulate client terminated connection

      expect(REDIS_TEST_CONNECTION).to receive(:publish).with("events:CONN_ID:_:terminate", [403, "This event was used for authentication twice"].to_json)

      Nostr::AuthenticationFlow.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION)
    end

    it "terminates current and previous connections of previous connection is active" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 5.seconds.ago)
      payload = CGI.escape(event.to_json)

      REDIS_TEST_CONNECTION.set("events22242:#{event.sha256}", "FIRST_CONN_ID") # simulate connection is active

      # hdel_mock.expect(:call, nil, ["connections_authenticators", "CONN_ID"])
      # hdel_mock.expect(:call, nil, ["authentications", "FIRST_CONN_ID"])

      expect(REDIS_TEST_CONNECTION).to receive(:publish).with("events:CONN_ID:_:terminate", [403, "This event was used for authentication twice"].to_json)
      expect(REDIS_TEST_CONNECTION).to receive(:publish).with("events:FIRST_CONN_ID:_:terminate", [403, "This event was used for authentication twice"].to_json)
      expect(REDIS_TEST_CONNECTION).to receive(:hdel).with("connections_authenticators", "CONN_ID")
      expect(REDIS_TEST_CONNECTION).to receive(:hdel).with("authentications", "FIRST_CONN_ID")

      Nostr::AuthenticationFlow.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION)
    end
  end

  describe "With invalid event data" do
    it "requires event of kind 22242" do
      event = build(:event, kind: 22243, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
      expect(Nostr::Nips::Nip43.call(event.as_json.stringify_keys)).to eq([nil, ["Kind 22243 is invalid for NIP-43 event, expected 22242"]])
    end

    it "requires created_at to be recent" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 1.year.ago)
      expect(Nostr::Nips::Nip43.call(event.as_json.stringify_keys)).to eq([nil, ["Created At is too old, expected window is 60 seconds"]])
    end

    it "requires created_at not to be in future" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.from_now)
      expect(Nostr::Nips::Nip43.call(event.as_json.stringify_keys)).to eq([nil, ["Created At is in the future"]])
    end

    it "requires proper relay-tag with pre-defined URL" do
      event = build(:event, kind: 22242, tags: [["relay", "http://example.com"]], created_at: 10.seconds.ago)
      expect(Nostr::Nips::Nip43.call(event.as_json.stringify_keys)).to eq([nil, ["Tag 'relay' has invalid value, expected ws://localhost:3000"]])
    end

    it "requires event.id to match payload" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
      event.sha256 = "INVALID"
      expect(Nostr::Nips::Nip43.call(event.as_json.stringify_keys)).to eq([nil, ["Id is invalid", "Signature is invalid"]])
    end

    it "requires event.signature to match payload" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
      event.sig = "INVALID"
      expect(Nostr::Nips::Nip43.call(event.as_json.stringify_keys)).to eq([nil, ["Signature is invalid"]])
    end
  end
end
