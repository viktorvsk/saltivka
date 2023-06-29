require "test_helper"

class Nostr::RelayControllerTest < ActiveSupport::TestCase
  describe Nostr::RelayController do
    before do
      @ws_sender = Minitest::Mock.new
      @random_connection_id = "CONN_ID"
      @sidekiq_pusher_mock_for = lambda do |klass, args|
        sidekiq_pusher = Minitest::Mock.new
        sidekiq_pusher.expect(:call, nil, [{
          "retry" => true,
          "backtrace" => false,
          "queue" => :nostr,
          "class" => klass,
          "args" => args
        }])
      end
      @valid_event = JSON.dump(JSON.parse(File.read(Rails.root.join("test", "fixtures", "files", "nostr_event_real.json"))))
    end

    subject do
      @ws_sender.expect(:call, nil, [["NOTICE", "error: #{@expected_error}"].to_json]) if @expected_error
      result = Nostr::RelayController.new(redis: REDIS_TEST_CONNECTION).perform(@nostr_event) do |notice|
        @ws_sender.call(notice)
      end
      @ws_sender.verify
      @pusher_mock&.verify

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

            @pusher_mock = @sidekiq_pusher_mock_for.call("NewSubscription", ["CONN_ID", "SUBID", "[{}]"])
            Sidekiq::Client.stub(:push, @pusher_mock) do
              SecureRandom.stub(:hex, @random_connection_id) do
                subject
              end
            end

            assert_equal REDIS_TEST_CONNECTION.smembers("client_reqs:CONN_ID"), ["SUBID"]
            assert_equal REDIS_TEST_CONNECTION.hgetall("subscriptions"), {"CONN_ID:SUBID" => "[{}]"}
          end

          it "fails when filters exceed maximum" do
            REDIS_TEST_CONNECTION.sadd("client_reqs:CONN_ID", "OTHER_SUBID")

            @nostr_event = ["REQ", "SUBID", {}].to_json
            @expected_error = %(Reached maximum of 1 subscriptions)
            RELAY_CONFIG.stub(:max_subscriptions, 1) do
              SecureRandom.stub(:hex, @random_connection_id) do
                subject
              end
            end
          end

          it "filters Events by kinds" do
            filters = {"kinds" => [1]}
            @nostr_event = ["REQ", "SUBID", filters].to_json

            @pusher_mock = @sidekiq_pusher_mock_for.call("NewSubscription", ["CONN_ID", "SUBID", [filters].to_json])
            Sidekiq::Client.stub(:push, @pusher_mock) do
              SecureRandom.stub(:hex, @random_connection_id) do
                subject
              end
            end

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

            SecureRandom.stub(:hex, @random_connection_id) do
              subject
            end

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
              @pusher_mock = @sidekiq_pusher_mock_for.call("NewEvent", ["CONN_ID", JSON.parse(@valid_event).to_json])
              Sidekiq::Client.stub(:push, @pusher_mock) do
                SecureRandom.stub(:hex, @random_connection_id) do
                  subject
                end
              end
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

          @pusher_mock = @sidekiq_pusher_mock_for.call("CountRequest", ["CONN_ID", "SUBID", "[{}]"])
          Sidekiq::Client.stub(:push, @pusher_mock) do
            SecureRandom.stub(:hex, @random_connection_id) do
              subject
            end
          end

          assert_equal REDIS_TEST_CONNECTION.smembers("client_reqs:CONN_ID"), []
          assert_equal REDIS_TEST_CONNECTION.hgetall("subscriptions"), {}
        end
      end
    end
  end
end
