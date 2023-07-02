require "test_helper"

class Nip13Test < ActiveSupport::TestCase
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

  test "NewEvent with id min PoW difficulty limits" do
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

  test "PoW difficulty" do
    with_pow = JSON.parse(File.read(Rails.root.join("test", "fixtures", "files", "nostr_event_pow.json")))
    event_with_pow = with_pow.merge({
      "created_at" => Time.at(with_pow["created_at"]),
      "sha256" => with_pow.delete("id"),
      "sig" => with_pow.delete("sig")
    })

    assert Event.new(event_with_pow).valid?
    assert @event.valid?
    RELAY_CONFIG.stub(:min_pow, 1) do
      assert Event.new(event_with_pow).valid?
      refute @event.valid?
    end
  end
end
