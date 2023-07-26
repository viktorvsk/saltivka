require "rails_helper"

RSpec.describe MemStore do
  describe ".authenticate!" do
    it "creates redis structures" do
      described_class.authenticate!(cid: "CONN_ID", event_sha256: "sha256", pubkey: "pubkey")
      expect(REDIS_TEST_CONNECTION.hget("authentications", "CONN_ID")).to eq("pubkey")
      expect(REDIS_TEST_CONNECTION.lpop("queue:nostr.nip42")).to eq({class: "AuthorizationRequest", args: ["CONN_ID", "sha256", "pubkey"]}.to_json)
    end
  end

  describe ".authorize!" do
    it "creates redis structures" do
      described_class.authorize!(cid: "CONN_ID", level: "100")
      expect(REDIS_TEST_CONNECTION.hget("authorizations", "CONN_ID")).to eq("100")
      expect(REDIS_TEST_CONNECTION.ttl("authorization_result:CONN_ID")).to eq(10)
      expect(REDIS_TEST_CONNECTION.lpop("authorization_result:CONN_ID")).to eq("100")
    end
  end

  describe ".fanout" do
    it "publishes to redis pubsub" do
      done = false
      Thread.new do
        REDIS_TEST_CONNECTION.psubscribe("events:*") do |on|
          on.pmessage do |_pattern, channel, event|
            assert_equal event, "DONE"
            assert_equal channel, "events:CONN_ID:_:ok"
            REDIS_TEST_CONNECTION.unsubscribe
            done = true
            Thread.current.exit
          end
        end
      end

      sleep(0.1)
      described_class.fanout(cid: "CONN_ID", command: :ok, payload: "DONE")
      sleep(0.1)
      assert done
    end
  end
end
