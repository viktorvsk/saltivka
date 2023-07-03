require "rails_helper"

RSpec.describe("NIP-42") do
  it "NewEvent with kind 22242 event authenticates pubkey" do
    REDIS_TEST_CONNECTION.sadd("connections", "CONN_ID")
    event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])

    expect(MemStore).to receive(:auth!).with(cid: "CONN_ID", pubkey: event.pubkey)

    NewEvent.perform_sync("CONN_ID", event.to_json)
  end

  it "NewEvent with kind 22242 event authenticates pubkey if already authenticated " do
    REDIS_TEST_CONNECTION.sadd("connections", "CONN_ID")
    event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])
    REDIS_TEST_CONNECTION.hset("authentications", "CONN_ID", event.pubkey)

    expect(MemStore).to receive(:auth!).with(cid: "CONN_ID", pubkey: event.pubkey)

    NewEvent.perform_sync("CONN_ID", event.to_json)
  end

  it "NewEvent with kind 22242 event does not authenticate pubkey if already authenticated and config restricts it" do
    REDIS_TEST_CONNECTION.sadd("connections", "CONN_ID")
    event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])
    REDIS_TEST_CONNECTION.hset("authentications", "CONN_ID", event.pubkey)

    allow(RELAY_CONFIG).to receive(:restrict_change_auth_pubkey).and_return(true)
    expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", command: :notice, payload: "This connection is already authenticated. To authenticate another pubkey please open new connection")

    NewEvent.perform_sync("CONN_ID", event.to_json)
  end

  describe "validates 22242 event according to NIP-43" do
    it "validates the 22242 event" do
      REDIS_TEST_CONNECTION.sadd("connections", "secret")
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "secret"]], created_at: 10.seconds.ago)
      expect(event).to be_valid
      expect(event.save).to be_falsey
      expect(event.errors[:kind]).to include("must not be ephemeral")
    end
  end

  describe "With invalid data" do
    it "checks that 'relay' tag host must match" do
      event = build(:event, kind: 22242, tags: [["relay", "http://invalid"], ["challenge", "secret"]], created_at: 10.seconds.ago)
      expect(event.save).to be_falsey
      expect(event.errors[:tags]).to include("'relay' must equal to ws://localhost:3000")
    end

    it "checks that 'challenge' tag must be present" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
      expect(event.save).to be_falsey
      expect(event.errors[:tags]).to include("'challenge' is missing")
    end

    it "checks that 'challenge' tag must match one in the database" do
      REDIS_TEST_CONNECTION.sadd("connections", "secret")
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "invalid"]], created_at: 10.seconds.ago)
      expect(event.save).to be_falsey
      expect(event.errors[:tags]).to include("'challenge' is invalid")
    end

    it "checks that created_at must not be too far in the past" do
      REDIS_TEST_CONNECTION.sadd("connections", "secret")
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "secret"]], created_at: 1.year.ago)
      expect(event.save).to be_falsey
      expect(event.errors[:created_at]).to include("is too old, must be within 600 seconds")
    end

    it "checks that created_at must not be in the future" do
      REDIS_TEST_CONNECTION.sadd("connections", "secret")
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "secret"]], created_at: 10.seconds.from_now)
      expect(event.save).to be_falsey
      expect(event.errors[:created_at]).to include("must not be in the future")
    end
  end
end
