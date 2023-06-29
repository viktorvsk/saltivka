require "test_helper"

class Nip43Test < ActiveSupport::TestCase
  test "basic" do
    event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
    assert_equal [event.pubkey, []], Nostr::Nips::Nip43.call(event.to_json)
  end
end
