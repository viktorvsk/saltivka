require "rails_helper"

RSpec.describe("NIP-43") do
  describe Nostr::AuthenticationFlow do
    context "with valid event of kind 22242" do
      it "authenticates connection pubkey" do
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 5.seconds.ago)
        payload = CGI.escape(event.to_json)

        subject.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION)

        expect(REDIS_TEST_CONNECTION.get("events22242:#{event.sha256}")).to eq("CONN_ID")
        expect(REDIS_TEST_CONNECTION.hget("authentications", "CONN_ID")).to eq(event.pubkey)
      end

      it "enqueues AuthorizationRequest job" do
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 5.seconds.ago)
        payload = CGI.escape(event.to_json)
        nostr_queue = Sidekiq::Queue.new("nostr")

        expect {
          subject.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION)
        }.to change { nostr_queue.size }.by(1)
        expect(nostr_queue.first.args).to match_array(["CONN_ID", event.sha256, event.pubkey])
      end

      context "when RELAY_CONFIG.forced_min_auth_level = 1" do
        before { allow(RELAY_CONFIG).to receive(:forced_min_auth_level).and_return(1) }

        it "gets higher authorization level from authorization request synchronously" do
          event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 5.seconds.ago)
          payload = CGI.escape(event.to_json)

          Thread.new do
            sleep(0.1)
            Redis.new(url: ENV["REDIS_URL"]).lpush("authorization_result:CONN_ID", "4") # emulate AuthorizationRequest job
          end

          subject.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |_|
            assert false # should not be here because only errors are yielded
          end

          expect(REDIS_TEST_CONNECTION.llen("authorization_result:CONN_ID")).to be_zero
        end

        it "gets lower authorization level from authorization request synchronously" do
          event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 5.seconds.ago)
          payload = CGI.escape(event.to_json)

          result = "connection was not terminated"

          REDIS_TEST_CONNECTION.lpush("authorization_result:CONN_ID", "0") # emulate AuthorizationRequest job and don't wait syncronously

          subject.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
            expect(message).to eq(["TERMINATE", "your account doesn't have required authorization (1)"])
            result = "TERMINATED"
          end

          expect(result).to eq("TERMINATED")
          expect(REDIS_TEST_CONNECTION.llen("authorization_result:CONN_ID")).to be_zero
        end

        it "does not allow to process 10002 events if min level of auth is forced"
      end
    end

    context "with invalid data for event 22242" do
      it "TERMINATEs for events with invalid JSON" do
        subject.call(ws_url: "ws://localhost?authorization=INVALID", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
          expect(message).to eq(["TERMINATE", "NIP-43 auth event has errors in JSON: unexpected token at 'INVALID'"])
        end
      end

      context "when RELAY_CONFIG.forced_min_auth_level = 0" do
        it "TERMINATEs for events with errors" do
          event = build(:event, kind: 22242, created_at: 5.seconds.ago)
          payload = CGI.escape(event.to_json)

          subject.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
            expect(message).to eq(["TERMINATE", "NIP-43 auth attempt is detected but auth event has errors: Tag 'relay' is missing"])
          end
        end
      end

      context "when RELAY_CONFIG.forced_min_auth_level = 1" do
        before { allow(RELAY_CONFIG).to receive(:forced_min_auth_level).and_return(1) }

        it "TERMINATEs when event is not provided" do
          subject.call(ws_url: "ws://localhost", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
            expect(message).to eq(["TERMINATE", "NIP-43 is forced over NIP-42 and auth event is missing in URL"])
          end
        end

        it "TERMINATEs for events with errors" do
          event = build(:event, kind: 22242, created_at: 5.seconds.ago)
          payload = CGI.escape(event.to_json)

          subject.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
            expect(message).to eq(["TERMINATE", "NIP-43 is forced over NIP-42 and auth event has errors: Tag 'relay' is missing"])
          end
        end
      end
    end

    context "with some unknown exception" do
      before { allow(Nostr::Nips::Nip43).to receive(:call).and_raise(ArgumentError, "something went wrong") }

      context "when RELAY_CONFIG.forced_min_auth_level = 0" do
        it "NOTICEs" do
          event = build(:event, kind: 22242, created_at: 5.seconds.ago)
          payload = CGI.escape(event.to_json)

          subject.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
            expect(message).to eq(["NOTICE", "error: ArgumentError something went wrong"])
          end
        end
      end

      context "when RELAY_CONFIG.forced_min_auth_level = 1" do
        before { allow(RELAY_CONFIG).to receive(:forced_min_auth_level).and_return(1) }
        it "TERMINATEs" do
          event = build(:event, kind: 22242, created_at: 5.seconds.ago)
          payload = CGI.escape(event.to_json)

          subject.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
            expect(message).to eq(["TERMINATE", "NIP-43 is forced over NIP-42 and something went wrong"])
          end
        end
      end
    end

    it "extracts valid pubkey from the 22242 event" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
      expect(Nostr::Nips::Nip43.call(event.as_json.stringify_keys)).to eq([event.pubkey, []])
    end

    it "terminates current connection if previous connection is active and auth-event key expired" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 61.seconds.ago)
      payload = CGI.escape(event.to_json)
      # Assumed state of Redis is like the following
      # REDIS_TEST_CONNECTION.hset("authentications", "FIRST_CONN_ID", event.pubkey)
      # REDIS_TEST_CONNECTION.del("events22242:#{event.sha256}")
      # But it doesn't actually make any difference
      # TODO: proper way to test it is using Timecop and time freeze

      subject.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
        expect(message).to eq(["TERMINATE", "NIP-43 auth attempt is detected but auth event has errors: Created At is too old, expected window is 60 seconds"])
      end
    end

    it "terminates current connection if previous connection is not present and auth-event key not yet expired" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 5.seconds.ago)
      payload = CGI.escape(event.to_json)

      REDIS_TEST_CONNECTION.set("events22242:#{event.sha256}", "") # simulate client terminated connection

      subject.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
        expect(message).to eq(["TERMINATE", "event with id #{event.sha256} was used for authentication twice"])
      end
    end

    it "terminates current and previous connections of previous connection is active" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 5.seconds.ago)
      payload = CGI.escape(event.to_json)

      REDIS_TEST_CONNECTION.set("events22242:#{event.sha256}", "FIRST_CONN_ID") # simulate connection is active

      # hdel_mock.expect(:call, nil, ["connections_authenticators", "CONN_ID"])
      # hdel_mock.expect(:call, nil, ["authentications", "FIRST_CONN_ID"])

      expect(REDIS_TEST_CONNECTION).to receive(:publish).with("events:FIRST_CONN_ID:_:terminate", [3403, "restricted: event with id #{event.sha256} was used for authentication twice"].to_json)
      expect(REDIS_TEST_CONNECTION).to receive(:hdel).with("connections_authenticators", "CONN_ID")
      expect(REDIS_TEST_CONNECTION).to receive(:hdel).with("authentications", "FIRST_CONN_ID")

      subject.call(ws_url: "ws://localhost?authorization=#{payload}", connection_id: "CONN_ID", redis: REDIS_TEST_CONNECTION) do |message|
        expect(message).to eq(["TERMINATE", "event with id #{event.sha256} was used for authentication twice"])
      end
    end
  end

  context "with invalid event data" do
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
