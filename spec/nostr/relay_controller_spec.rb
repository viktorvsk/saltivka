require "rails_helper"

RSpec.describe Nostr::RelayController do
  before do
    @random_connection_id = "CONN_ID"
    @ws_sender = double
    @expect_sidekiq_push = lambda do |klass, args|
      expect(Sidekiq::Client).to receive(:push).with({
        "retry" => true,
        "backtrace" => false,
        "queue" => :nostr,
        "class" => klass,
        "args" => args
      })
    end
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

    describe "NIP-01" do
      describe "REQ" do
        it "saves connection_id and subscription_id to redis, adds channel to pubsub listener and adds NewSubscription to Sidekiq queue" do
          @nostr_event = ["REQ", "SUBID", {}].to_json

          @expect_sidekiq_push.call("NewSubscription", ["CONN_ID", "SUBID", "[{}]"])

          subject

          assert_equal REDIS_TEST_CONNECTION.smembers("client_reqs:CONN_ID"), ["SUBID"]
          assert_equal REDIS_TEST_CONNECTION.hgetall("subscriptions"), {"CONN_ID:SUBID" => "[{}]"}
        end

        it "fails when filters exceed maximum" do
          REDIS_TEST_CONNECTION.sadd("client_reqs:CONN_ID", "OTHER_SUBID")

          @nostr_event = ["REQ", "SUBID", {}].to_json
          @expected_error = %(Reached maximum of 1 subscriptions)
          allow(RELAY_CONFIG).to receive(:max_subscriptions).and_return(1)
          subject
        end

        it "filters Events by kinds" do
          filters = {"kinds" => [1]}
          @nostr_event = ["REQ", "SUBID", filters].to_json

          @expect_sidekiq_push.call("NewSubscription", ["CONN_ID", "SUBID", [filters].to_json])

          subject

          assert_equal REDIS_TEST_CONNECTION.smembers("client_reqs:CONN_ID"), ["SUBID"]
          assert_equal REDIS_TEST_CONNECTION.hgetall("subscriptions"), {"CONN_ID:SUBID" => [filters].to_json}
        end

        describe "with invalid args" do
          it "responds with error given multiple filters of invalid type" do
            @expected_error = %(property '/1' is not of type: object; property '/2' is not of type: object)
            @nostr_event = ["REQ", "SUBID", [], "UNKNOWN ARG"].to_json
            subject
          end

          it "responds with error when some filter sets are invalid" do
            @expected_error = %(property '/1' is not of type: object)
            @nostr_event = ["REQ", "SUBID", 1].to_json
            subject
          end

          it "responds with error when some filter sets values are invalid" do
            @expected_error = %(property '/1/kinds/0' is not of type: integer)
            @nostr_event = ["REQ", "SUBID", {kinds: [{}]}].to_json
            subject
          end

          it "responds with error when filters/until < filters/since" do
            @expected_error = %(when both specified, until has always to be after since)
            @nostr_event = ["REQ", "SUBID", {until: 2.days.ago.to_i, since: 1.day.ago.to_i}].to_json
            subject
          end
        end
      end

      describe "CLOSE" do
        before do
          REDIS_TEST_CONNECTION.sadd("client_reqs:CONN_ID", "XYZ123")
        end

        it "removes redis data and unsubscribes from one service" do
          @nostr_event = ["CLOSE", "XYZ123"].to_json

          subject

          assert_nil REDIS_TEST_CONNECTION.get("client_reqs:CONN_ID")
          assert_empty REDIS_TEST_CONNECTION.hkeys("subscriptions")
        end

        describe "with invalid args" do
          it "responds with error (additional args)" do
            @expected_error = "root is invalid: error_type=maxItems"
            @nostr_event = ["CLOSE", "SUBID", "UNKNOWN ARG"].to_json
            subject
          end

          it "responds with error (wrong arg)" do
            @expected_error = "property '/0' is not of type: string"
            @nostr_event = ["CLOSE", 1234].to_json
            subject
          end
        end
      end

      describe "EVENT" do
        describe "with valid Event data" do
          it "pushes Event to Sidekiq" do
            @nostr_event = ["EVENT", JSON.parse(@valid_event)].to_json
            @expect_sidekiq_push.call("NewEvent", ["CONN_ID", JSON.parse(@valid_event).to_json])

            subject
          end
        end

        describe "with invalid Event data" do
          it "notices invalid Event `id` length" do
            @expected_error = "property '/0/id' is invalid: error_type=minLength"
            @nostr_event = ["EVENT", JSON.parse(@valid_event).merge("id" => "INVALID")].to_json
            subject
          end

          it "notices invalid Event `id`" do
            @expected_error = "property '/0/id' doesn't match"
            @nostr_event = ["EVENT", JSON.parse(@valid_event).merge("id" => "00003ea43d2fd2873a9b3191a8e5fdef381ebf2a1c56ca909861fe9489671c65")].to_json
            subject
          end

          it "notices additional arguments" do
            @expected_error = "root is invalid: error_type=maxItems"
            @nostr_event = ["EVENT", JSON.parse(@valid_event), "INVALID ARG"].to_json
            subject
          end

          it "notices invalid Event `sig` length" do
            @expected_error = "property '/0/sig' is invalid: error_type=minLength"
            @nostr_event = ["EVENT", JSON.parse(@valid_event).merge("sig" => "INVALID")].to_json
            subject
          end

          it "notices invalid Event `sig`" do
            @expected_error = "property '/0/sig' doesn't match"
            @nostr_event = ["EVENT", JSON.parse(@valid_event).merge("sig" => "00000f64cfa9945c4a1ea1f7edea8942a84a1d4ee9b36e4e851bda396590f10a11a49519d4859c7c99c1d180bc3feffcad85b9d62a98748decbfc6ed686f5aeb")].to_json
            subject
          end

          it "notices malformed JSON" do
            @expected_error = "property '/0' is not of type: object"
            @nostr_event = ["EVENT", ""].to_json
            subject
          end

          it "notices empty JSON" do
            @expected_error = "property '/0' is missing required keys: content, created_at, id, kind, pubkey, sig, tags"
            @nostr_event = ["EVENT", {}].to_json
            subject
          end
        end
      end
    end

    describe "NIP-45" do
      it "pushes event to Sidekiq" do
        @nostr_event = ["COUNT", "SUBID", {}].to_json

        @expect_sidekiq_push.call("CountRequest", ["CONN_ID", "SUBID", "[{}]"])

        subject

        assert_equal REDIS_TEST_CONNECTION.smembers("client_reqs:CONN_ID"), []
        assert_equal REDIS_TEST_CONNECTION.hgetall("subscriptions"), {}
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

      controller = Nostr::RelayController.new(cid)

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
end
