require "test_helper"

class NewSubscriptionTest < ActiveSupport::TestCase
  setup do
    sk = "945e01e37662430162121b804d3645a86d97df9d256917d86735d0eb219393eb"
    pk = "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"
    sha256 = "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"
    sig = Schnorr.sign([sha256].pack("H*"), [sk].pack("H*")).encode.unpack1("H*")
    event_params = {
      created_at: Time.at(1687183979),
      kind: 0,
      tags: [],
      content: "",
      sha256: sha256,
      sig: sig,
      pubkey: pk
    }

    @event = Event.create!(event_params)
  end

  test "works with empty filters array" do
    redis_publisher = Minitest::Mock.new
    redis_publisher.expect(:call, nil, ["events:CONN_ID:SUBID:found_event", @event.to_json])
    redis_publisher.expect(:call, nil, ["events:CONN_ID:SUBID:found_end", "EOSE"])

    REDIS.stub(:publish, redis_publisher) { NewSubscription.perform_sync("CONN_ID", "SUBID", "[]") }
    redis_publisher.verify
  end

  test "works with filter_set instead of filters" do
    redis_publisher = Minitest::Mock.new
    redis_publisher.expect(:call, nil, ["events:CONN_ID:SUBID:found_event", @event.to_json])
    redis_publisher.expect(:call, nil, ["events:CONN_ID:SUBID:found_end", "EOSE"])

    REDIS.stub(:publish, redis_publisher) { NewSubscription.perform_sync("CONN_ID", "SUBID", {kinds: [0], authors: ["a19f19f"]}.to_json) }
    redis_publisher.verify
  end

  test "works with empty filter_set" do
    redis_publisher = Minitest::Mock.new
    redis_publisher.expect(:call, nil, ["events:CONN_ID:SUBID:found_event", @event.to_json])
    redis_publisher.expect(:call, nil, ["events:CONN_ID:SUBID:found_end", "EOSE"])

    REDIS.stub(:publish, redis_publisher) { NewSubscription.perform_sync("CONN_ID", "SUBID", "[{}]") }
    redis_publisher.verify
  end

  test "does nothing when provided JSON is invalid" do
    redis_publisher = Minitest::Mock.new
    REDIS.stub(:publish, redis_publisher) { NewSubscription.perform_sync("CONN_ID", "SUBID", "INVALID") }
    redis_publisher.verify
  end

  test "does nothing when provided connection_id is empty" do
    REDIS.stub(:publish, proc { raise "failed" }) { NewSubscription.perform_sync("", "", "[]") }
  end
end
