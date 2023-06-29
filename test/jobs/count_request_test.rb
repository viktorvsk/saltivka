require "test_helper"

class CountRequestTest < ActiveSupport::TestCase
  test "works with empty filters array" do
    create(:event, kind: 123)
    redis_publisher = Minitest::Mock.new
    redis_publisher.expect(:call, nil, ["events:CONN_ID:SUBID:count", "1"])

    REDIS.stub(:publish, redis_publisher) { CountRequest.new.perform("CONN_ID", "SUBID", "[]") }
    redis_publisher.verify
  end

  test "works with filter_set instead of filters" do
    create(:event, kind: 0, pubkey: FAKE_CREDENTIALS[:alice][:pk])
    redis_publisher = Minitest::Mock.new
    redis_publisher.expect(:call, nil, ["events:CONN_ID:SUBID:count", "1"])

    REDIS.stub(:publish, redis_publisher) { CountRequest.new.perform("CONN_ID", "SUBID", {kinds: [0], authors: ["a19f19f"]}.to_json) }
    redis_publisher.verify
  end

  test "works with empty filter_set" do
    create(:event, kind: 123)
    redis_publisher = Minitest::Mock.new
    redis_publisher.expect(:call, nil, ["events:CONN_ID:SUBID:count", "1"])

    REDIS.stub(:publish, redis_publisher) { CountRequest.new.perform("CONN_ID", "SUBID", "[{}]") }
    redis_publisher.verify
  end

  test "does nothing when provided JSON is invalid" do
    redis_publisher = Minitest::Mock.new
    REDIS.stub(:publish, redis_publisher) { CountRequest.new.perform("CONN_ID", "SUBID", "INVALID") }
    redis_publisher.verify
  end

  test "does nothing when provided connection_id is empty" do
    REDIS.stub(:publish, proc { raise "failed" }) { CountRequest.new.perform("", "", "[]") }
  end
end
