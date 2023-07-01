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
  end
end
