require "test_helper"

class CountRequestTest < ActiveSupport::TestCase
  setup do
    sk = "945e01e37662430162121b804d3645a86d97df9d256917d86735d0eb219393eb"
    pk = "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"
    event_digest = "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"
    sig = Schnorr.sign([event_digest].pack("H*"), [sk].pack("H*")).encode.unpack1("H*")
    event_params = {
      created_at: Time.at(1687183979),
      kind: 0,
      tags: [],
      content: "",
      digest_and_sig: [event_digest, sig],
      pubkey: pk
    }

    @event = Event.create!(event_params)
  end

  test "works with empty filters array" do
    redis_publisher = Minitest::Mock.new
    redis_publisher.expect(:call, nil, ["events:CONN_ID:SUBID:count", "1"])

    REDIS.stub(:publish, redis_publisher) { CountRequest.perform_sync("CONN_ID", "SUBID", "[]") }
    redis_publisher.verify
  end
end