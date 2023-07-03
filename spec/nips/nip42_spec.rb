require "rails_helper"

RSpec.describe("NIP-42") do
  describe NewEvent do
    context "given a valid event of kind 22242" do
      it "authenticates pubkey" do
        REDIS_TEST_CONNECTION.sadd("connections", "CONN_ID")
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])

        expect(MemStore).to receive(:auth!).with(cid: "CONN_ID", pubkey: event.pubkey)

        subject.perform("CONN_ID", event.to_json)
      end

      it "authenticates pubkey if already authenticated" do
        REDIS_TEST_CONNECTION.sadd("connections", "CONN_ID")
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])
        REDIS_TEST_CONNECTION.hset("authentications", "CONN_ID", event.pubkey)

        expect(MemStore).to receive(:auth!).with(cid: "CONN_ID", pubkey: event.pubkey)

        subject.perform("CONN_ID", event.to_json)
      end

      it "does not authenticate pubkey if already authenticated and config restricts it" do
        REDIS_TEST_CONNECTION.sadd("connections", "CONN_ID")
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])
        REDIS_TEST_CONNECTION.hset("authentications", "CONN_ID", event.pubkey)

        allow(RELAY_CONFIG).to receive(:restrict_change_auth_pubkey).and_return(true)
        expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", command: :notice, payload: "This connection is already authenticated. To authenticate another pubkey please open new connection")

        subject.perform("CONN_ID", event.to_json)
      end
    end
  end

  describe Event do
    it "fails to persist with valid data since it has an ephemeral kind" do
      REDIS_TEST_CONNECTION.sadd("connections", "secret")
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "secret"]], created_at: 10.seconds.ago)
      expect(event).to be_valid
      expect(event.save).to be_falsey
      expect(event.errors[:kind]).to include("must not be ephemeral")
    end

    describe "With invalid data" do
      it "requires relay-tag host to match" do
        event = build(:event, kind: 22242, tags: [["relay", "http://invalid"], ["challenge", "secret"]], created_at: 10.seconds.ago)
        expect(event.save).to be_falsey
        expect(event.errors[:tags]).to include("'relay' must equal to ws://localhost:3000")
      end

      it "requires challenge-tag to be present" do
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
        expect(event.save).to be_falsey
        expect(event.errors[:tags]).to include("'challenge' is missing")
      end

      it "requires challenge-tag to match one in the database" do
        REDIS_TEST_CONNECTION.sadd("connections", "secret")
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "invalid"]], created_at: 10.seconds.ago)
        expect(event.save).to be_falsey
        expect(event.errors[:tags]).to include("'challenge' is invalid")
      end

      it "requires created_at to not be too far in the past" do
        REDIS_TEST_CONNECTION.sadd("connections", "secret")
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "secret"]], created_at: 1.year.ago)
        expect(event.save).to be_falsey
        expect(event.errors[:created_at]).to include("is too old, must be within 600 seconds")
      end

      it "requires created_at to not be in the future" do
        REDIS_TEST_CONNECTION.sadd("connections", "secret")
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "secret"]], created_at: 10.seconds.from_now)
        expect(event.save).to be_falsey
        expect(event.errors[:created_at]).to include("must not be in the future")
      end
    end
  end
end
