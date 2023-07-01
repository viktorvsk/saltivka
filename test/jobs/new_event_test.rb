require "test_helper"

class NewEventTest < ActiveSupport::TestCase
  setup do
  end

  test "NIP-20 test OK response" do
    event = build(:event, kind: 555)
    publish_mock = MiniTest::Mock.new
    publish_mock.expect :call, nil, ["events:CONN_ID:_:ok", ["OK", event.sha256, true, ""].to_json]
    REDIS.stub(:publish, publish_mock) do
      NewEvent.perform_sync("CONN_ID", event.to_json)
    end
    publish_mock.verify
  end

  test "NIP-20 test ephemeral event doesn't send OK on success and does not get stored in database" do
    REDIS_TEST_CONNECTION.hset("subscriptions", "CONN_ID:SUBID", "[{\"kinds\": [20000]}]")
    event = build(:event, kind: 20000)
    publish_mock = MiniTest::Mock.new
    publish_mock.expect :call, nil, ["events:CONN_ID:SUBID:found_event", event.to_json]
    REDIS.stub(:publish, publish_mock) do
      NewEvent.perform_sync("CONN_ID", event.to_json)
    end
    refute Event.where(sha256: event.sha256).exists?
    publish_mock.verify
  end

  test "created_at limits NIP-22" do
    event = build(:event, kind: 1, created_at: 1.day.ago)
    publish_mock = MiniTest::Mock.new
    publish_mock.expect :call, nil, ["events:CONN_ID:_:ok", ["OK", event.sha256, false, "error: Created at must be within limits"].to_json]

    RELAY_CONFIG.stub(:created_at_in_past, 1000) do
      REDIS.stub(:publish, publish_mock) do
        NewEvent.perform_sync("CONN_ID", event.to_json)
      end
    end

    publish_mock.verify
  end

  test "id min PoW difficulty limits NIP-13" do
    event = build(:event, kind: 1, created_at: 1.day.ago)
    publish_mock = MiniTest::Mock.new
    publish_mock.expect :call, nil, ["events:CONN_ID:_:ok", ["OK", event.sha256, false, "pow: min difficulty must be 1000, got #{event.pow_difficulty}"].to_json]

    RELAY_CONFIG.stub(:min_pow, 1000) do
      REDIS.stub(:publish, publish_mock) do
        NewEvent.perform_sync("CONN_ID", event.to_json)
      end
    end

    publish_mock.verify
  end

  test "NIP-42: kind 22242 event authenticates pubkey" do
    REDIS.sadd("connections", "CONN_ID")
    event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])
    redis_mock = MiniTest::Mock.new
    redis_mock.expect :call, nil, ["authentications", "CONN_ID", event.pubkey]
    REDIS.stub(:hset, redis_mock) do
      NewEvent.perform_sync("CONN_ID", event.to_json)
    end
    redis_mock.verify
  end

  test "NIP-42: kind 22242 event authenticates pubkey if already authenticated " do
    REDIS.sadd("connections", "CONN_ID")
    event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])
    REDIS.hset("authentications", "CONN_ID", event.pubkey)
    redis_mock = MiniTest::Mock.new
    redis_mock.expect :call, nil, ["authentications", "CONN_ID", event.pubkey]
    REDIS.stub(:hset, redis_mock) do
      NewEvent.perform_sync("CONN_ID", event.to_json)
    end
    redis_mock.verify
  end

  test "NIP-42: kind 22242 event does not authenticate pubkey if already authenticated and config restricts it" do
    REDIS.sadd("connections", "CONN_ID")
    event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])
    REDIS.hset("authentications", "CONN_ID", event.pubkey)
    publish_mock = MiniTest::Mock.new
    hset_mock = MiniTest::Mock.new
    publish_mock.expect :call, nil, ["events:CONN_ID:_:notice", "This connection is already authenticated. To authenticate another pubkey please open new connection"]
    REDIS.stub(:publish, publish_mock) do
      REDIS.stub(:hset, hset_mock) do
        RELAY_CONFIG.stub(:restrict_change_auth_pubkey, true) do
          NewEvent.perform_sync("CONN_ID", event.to_json)
        end
      end
    end
    publish_mock.verify
  end

  test "NIP-20: duplicate OK message" do
    event = create(:event)
    redis_mock = Minitest::Mock.new
    redis_mock.expect(:call, nil, ["events:CONN_ID:_:ok", ["OK", event.sha256, false, "duplicate: this event is already present in the database"].to_json])

    REDIS.stub(:publish, redis_mock) do
      NewEvent.perform_sync("CONN_ID", event.to_json)
    end

    redis_mock.verify
  end
end
