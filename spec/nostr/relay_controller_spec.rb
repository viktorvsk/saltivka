require "rails_helper"

RSpec.describe Nostr::RelayController do
  before do
    @random_connection_id = "CONN_ID"
    @valid_event = JSON.dump(JSON.parse(File.read(Rails.root.join("spec", "support", "nostr_event_real.json"))))
  end

  subject do
    allow(SecureRandom).to receive(:hex).and_return(@random_connection_id)
    result = Nostr::RelayController.new.perform(event_data: @nostr_event, redis: REDIS_TEST_CONNECTION) do |notice|
      expect(notice).to eq(["NOTICE", "error: #{@expected_error}"].to_json) if @expected_error
    end

    result
  end

  describe "#perform" do
    describe "with invalid" do
      it "notices malformed JSON" do
        @expected_error = "malformed JSON"
        @nostr_event = ""
        subject
      end

      it "notices invalid command" do
        @expected_error = "unexpected command: 'UNKNOWN'"
        @nostr_event = '["UNKNOWN"]'
        subject
      end

      it "notices empty command" do
        @expected_error = "unexpected command: ''"
        @nostr_event = '["", 1, 2]'
        subject
      end
    end
  end

  describe "#terminate" do
    it "cleans up redis resources related to connection" do
      cid = "CONN_ID"
      REDIS_TEST_CONNECTION.sadd("client_reqs:#{cid}", "SUBID")
      REDIS_TEST_CONNECTION.sadd("connections", "OTHER_CONN_ID")
      REDIS_TEST_CONNECTION.sadd("connections", cid)
      REDIS_TEST_CONNECTION.hset("connections_authenticators", cid, "event22242_id")
      REDIS_TEST_CONNECTION.hset("subscriptions", "#{cid}:SUBID", "{}")
      REDIS_TEST_CONNECTION.call("SET", "events22242:event22242_id", cid, "EX", "100")

      controller = Nostr::RelayController.new

      allow(controller).to receive(:connection_id).and_return(cid)

      controller.terminate(event: cid, redis: REDIS_TEST_CONNECTION)

      assert_equal 0, REDIS_TEST_CONNECTION.exists("client_reqs:#{cid}")
      refute REDIS_TEST_CONNECTION.sismember("connections", cid)
      assert_equal 1, REDIS_TEST_CONNECTION.scard("connections")
      refute REDIS_TEST_CONNECTION.hexists("connections_authenticators", cid)
      refute REDIS_TEST_CONNECTION.hexists("subscriptions", "#{cid}:SUBID")
      assert_equal "", REDIS_TEST_CONNECTION.get("events22242:event22242_id")
      sleep(1)
      assert_includes [99, 98], REDIS_TEST_CONNECTION.ttl("events22242:event22242_id")
    end
  end

  describe "#authorized?" do
    subject do
      allow(SecureRandom).to receive(:hex).and_return(@random_connection_id)
      result = Nostr::RelayController.new.perform(event_data: @nostr_event, redis: REDIS_TEST_CONNECTION) do |notice|
        expect(notice).to eq(["NOTICE", @expected_error].to_json) if @expected_error
      end

      result
    end
    it "NOTICEs when not authorized" do
      allow(RELAY_CONFIG).to receive(:required_auth_level_for_req).and_return(1)

      @expected_error = "restricted: your account doesn't have required authorization level"
      @nostr_event = ["REQ", "SUBID", {}].to_json
      subject
    end
  end
end
