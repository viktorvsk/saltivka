require "test_helper"

class Nostr::AuthenticationFlowTest < ActiveSupport::TestCase
  test "handles invalid JSON" do
    Nostr::AuthenticationFlow.call("ws://localhost?authorization=INVALID", "CONN_ID") do |message|
      assert_equal message, ["NOTICE", "error: unexpected token at 'INVALID'"].to_json
    end
  end

  test "Falls back to NIP-42 if authorization param is not present" do
    Nostr::AuthenticationFlow.call("ws://localhost?authorization=", "CONN_ID") do |message|
      assert_equal message, ["AUTH", "CONN_ID"].to_json
    end
  end

  test "NIP-43: Authenticates valid kind22242 event" do
    event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 5.seconds.ago)
    payload = CGI.escape(event.to_json)
    Nostr::AuthenticationFlow.call("ws://localhost?authorization=#{payload}", "CONN_ID")
    assert_equal "CONN_ID", REDIS_TEST_CONNECTION.get("events22242:#{event.sha256}")
    assert_equal event.pubkey, REDIS_TEST_CONNECTION.hget("authentications", "CONN_ID")
  end

  test "NIP-43: NOTICEs validation errors for event 22242" do
    event = build(:event, kind: 22242, created_at: 5.seconds.ago)
    payload = CGI.escape(event.to_json)
    Nostr::AuthenticationFlow.call("ws://localhost?authorization=#{payload}", "CONN_ID") do |message|
      assert_equal message, ["NOTICE", "error: Tag 'relay' is missing"].to_json
    end
  end

  test "NIP-43: connection is not present but key not yet expired" do
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

  test "NIP-43: connection is active" do
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

  test "NIP-43: connection is active but key is expired" do
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
