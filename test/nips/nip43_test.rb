require "test_helper"

class Nip43Test < ActiveSupport::TestCase
  test "validates 22242 event according to NIP-43" do
    event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
    assert_equal [event.pubkey, []], Nostr::Nips::Nip43.call(event.as_json.stringify_keys)
  end

  class WithInvalidDataTest < Nip43Test
    test "expects 22242 event kind" do
      event = build(:event, kind: 22243, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
      assert_equal [nil, ["Kind 22243 is invalid for NIP-43 event, expected 22242"]], Nostr::Nips::Nip43.call(event.as_json.stringify_keys)
    end

    test "validates created_at too old" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 1.year.ago)
      assert_equal [nil, ["Created At is too old, expected window is 60 seconds"]], Nostr::Nips::Nip43.call(event.as_json.stringify_keys)
    end

    test "validates created_at in future" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.from_now)
      assert_equal [nil, ["Created At is in future"]], Nostr::Nips::Nip43.call(event.as_json.stringify_keys)
    end

    test "validates relay URL" do
      event = build(:event, kind: 22242, tags: [["relay", "http://example.com"]], created_at: 10.seconds.ago)
      assert_equal [nil, ["Tag 'relay' has invalid value, expected ws://localhost:3000"]], Nostr::Nips::Nip43.call(event.as_json.stringify_keys)
    end

    test "validates ID" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
      event.sha256 = "INVALID"
      assert_equal [nil, ["Id is invalid", "Signature is invalid"]], Nostr::Nips::Nip43.call(event.as_json.stringify_keys)
    end

    test "validates signature" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
      event.sig = "INVALID"
      assert_equal [nil, ["Signature is invalid"]], Nostr::Nips::Nip43.call(event.as_json.stringify_keys)
    end

    class AuthenticationFlow < Nip43Test
      test "Authenticates valid kind22242 event" do
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 5.seconds.ago)
        payload = CGI.escape(event.to_json)
        Nostr::AuthenticationFlow.call("ws://localhost?authorization=#{payload}", "CONN_ID")
        assert_equal "CONN_ID", REDIS_TEST_CONNECTION.get("events22242:#{event.sha256}")
        assert_equal event.pubkey, REDIS_TEST_CONNECTION.hget("authentications", "CONN_ID")
      end

      test "NOTICEs validation errors for event 22242" do
        event = build(:event, kind: 22242, created_at: 5.seconds.ago)
        payload = CGI.escape(event.to_json)
        Nostr::AuthenticationFlow.call("ws://localhost?authorization=#{payload}", "CONN_ID") do |message|
          assert_equal message, ["NOTICE", "error: Tag 'relay' is missing"].to_json
        end
      end

      test "connection is not present but key not yet expired" do
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 5.seconds.ago)
        payload = CGI.escape(event.to_json)

        REDIS_TEST_CONNECTION.set("events22242:#{event.sha256}", "") # simulate client terminated connection

        publish_mock = MiniTest::Mock.new
        publish_mock.expect(:call, nil, ["events:CONN_ID:_:terminate", [403, "This event was used for authentication twice"].to_json])

        REDIS.stub(:publish, publish_mock) do
          Nostr::AuthenticationFlow.call("ws://localhost?authorization=#{payload}", "CONN_ID")
        end

        publish_mock.verify
      end

      test "connection is active" do
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 5.seconds.ago)
        payload = CGI.escape(event.to_json)

        REDIS_TEST_CONNECTION.set("events22242:#{event.sha256}", "FIRST_CONN_ID") # simulate connection is active

        publish_mock = MiniTest::Mock.new
        publish_mock.expect(:call, nil, ["events:CONN_ID:_:terminate", [403, "This event was used for authentication twice"].to_json])
        publish_mock.expect(:call, nil, ["events:FIRST_CONN_ID:_:terminate", [403, "This event was used for authentication twice"].to_json])

        hdel_mock = MiniTest::Mock.new
        hdel_mock.expect(:call, nil, ["connections_authenticators", "CONN_ID"])
        hdel_mock.expect(:call, nil, ["authentications", "FIRST_CONN_ID"])

        REDIS.stub(:publish, publish_mock) do
          REDIS.stub(:hdel, hdel_mock) do
            Nostr::AuthenticationFlow.call("ws://localhost?authorization=#{payload}", "CONN_ID")
          end
        end

        publish_mock.verify
      end

      test "connection is active but key is expired" do
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 61.seconds.ago)
        payload = CGI.escape(event.to_json)
        # Assumed state of Redis is like the following
        # REDIS_TEST_CONNECTION.hset("authentications", "FIRST_CONN_ID", event.pubkey)
        # REDIS_TEST_CONNECTION.del("events22242:#{event.sha256}")
        # But it doesn't actually make any difference
        # TODO: proper way to test it is using Timecop and time freeze
        Nostr::AuthenticationFlow.call("ws://localhost?authorization=#{payload}", "CONN_ID") do |message|
          assert_equal message, ["NOTICE", "error: Created At is too old, expected window is 60 seconds"].to_json
        end
      end
    end
  end
end
