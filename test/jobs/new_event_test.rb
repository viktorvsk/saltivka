require "test_helper"

class NewEventTest < ActiveSupport::TestCase
  setup do
  end

  test "NIP-20 test OK response" do
    event = build(:event, kind: 555)
    publish_mock = MiniTest::Mock.new
    publish_mock.expect :call, nil, ["events:CONN_ID:_:ok", ["OK", event.id, true, ""].to_json]
    REDIS.stub(:publish, publish_mock) do
      NewEvent.perform_sync("CONN_ID", event.to_json)
    end
    publish_mock.verify
  end

  test "NIP-33 test ephemeral event doesn't send OK on success" do
    REDIS_TEST_CONNECTION.hset("subscriptions", "CONN_ID:SUBID", "[{\"kinds\": [20000]}]")
    event = build(:event, kind: 20000)
    publish_mock = MiniTest::Mock.new
    publish_mock.expect :call, nil, ["events:CONN_ID:SUBID:found_event", event.to_json]
    REDIS.stub(:publish, publish_mock) do
      NewEvent.perform_sync("CONN_ID", event.to_json)
    end
    publish_mock.verify
  end

  test "created_at limits NIP-22" do
    event = build(:event, kind: 1, created_at: 1.day.ago)
    publish_mock = MiniTest::Mock.new
    publish_mock.expect :call, nil, ["events:CONN_ID:_:ok", ["OK", event.id, false, "error: Created at must be within limits"].to_json]

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
    publish_mock.expect :call, nil, ["events:CONN_ID:_:ok", ["OK", event.id, false, "pow: min difficulty must be 1000, got #{event.pow_difficulty}"].to_json]

    RELAY_CONFIG.stub(:min_pow, 1000) do
      REDIS.stub(:publish, publish_mock) do
        NewEvent.perform_sync("CONN_ID", event.to_json)
      end
    end

    publish_mock.verify
  end
end
