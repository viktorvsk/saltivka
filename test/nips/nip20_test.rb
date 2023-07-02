require "test_helper"

class Nip20Test < ActiveSupport::TestCase
  test "NewEvent responds with OK" do
    event = build(:event, kind: 555)
    publish_mock = MiniTest::Mock.new
    publish_mock.expect :call, nil, ["events:CONN_ID:_:ok", ["OK", event.sha256, true, ""].to_json]
    REDIS.stub(:publish, publish_mock) do
      NewEvent.perform_sync("CONN_ID", event.to_json)
    end
    publish_mock.verify
  end

  test "NewEvent given ephemeral event doesn't send OK on success and does not get stored in database" do
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

  test "NewEvent responds with duplicate: OK message" do
    event = create(:event)
    redis_mock = Minitest::Mock.new
    redis_mock.expect(:call, nil, ["events:CONN_ID:_:ok", ["OK", event.sha256, false, "duplicate: this event is already present in the database"].to_json])

    REDIS.stub(:publish, redis_mock) do
      NewEvent.perform_sync("CONN_ID", event.to_json)
    end

    redis_mock.verify
  end
end
