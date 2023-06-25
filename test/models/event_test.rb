require "test_helper"

class EventTest < ActiveSupport::TestCase
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
      pubkey: pk,
      digest_and_sig: [event_digest, sig]
    }

    @event = Event.create!(event_params)
  end

  test "nostr format serialization" do
    assert true, @event.persisted?
    assert "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f", Digest::SHA256.hexdigest(JSON.dump(@event.to_nostr_serialized))
  end

  test "Single event matching filter_set" do
    event_with_tags = create(:event, kind: 1, tags: [["e", "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"], ["p", "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]])
    assert_equal true, @event.matches_nostr_filter_set?({"ids" => ["bf84a73"]})
    assert_equal true, @event.matches_nostr_filter_set?({"authors" => ["a19f19f"]})
    assert_equal false, @event.matches_nostr_filter_set?({"authors" => ["_a19f19f"]})

    assert_equal true, event_with_tags.matches_nostr_filter_set?({"#e" => ["bf84a"]})
    assert_equal true, event_with_tags.matches_nostr_filter_set?({"#p" => ["a19f19"]})
    assert_equal false, event_with_tags.matches_nostr_filter_set?({"#e" => ["a19f19"]})

    assert_equal true, build(:event, kind: 4).matches_nostr_filter_set?({"kinds" => [4]})
    assert_equal false, build(:event, kind: 3).matches_nostr_filter_set?({"kinds" => [4]})
    assert_equal false, build(:event, kind: 4, created_at: 1.hour.ago).matches_nostr_filter_set?({"kinds" => [4], "until" => 2.days.ago.to_i})
    assert_equal true, build(:event, kind: 4, created_at: 1.day.ago).matches_nostr_filter_set?({"kinds" => [4], "until" => 2.hour.ago.to_i})
    assert_equal true, build(:event, created_at: 1.hour.ago).matches_nostr_filter_set?({"since" => 2.days.ago.to_i})
    assert_equal false, build(:event, created_at: 1.day.ago).matches_nostr_filter_set?({"since" => 2.hour.ago.to_i})
  end

  # Here we test a use case where we have implemented new filter
  # added it to AVAILABLE FILTERS but for some reason missed to handle it
  test "edge filter" do
    RELAY_CONFIG.stub(:available_filters, %w[kinds ids authors #e #p since until edge_filter]) do
      assert_equal false, build(:event).matches_nostr_filter_set?({"edge_filter" => 2.hour.ago.to_i})
    end
  end

  test "Find Events mathcing filter_set in database" do
    event_with_tags = create(:event, kind: 1, tags: [["e", "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"], ["p", "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]])

    assert_equal 2, Event.by_nostr_filters({}).count
    assert_equal 1, Event.by_nostr_filters({limit: 1}).count
    assert_equal 1, Event.by_nostr_filters({kinds: 0}).count
    assert_equal 2, Event.by_nostr_filters({"authors" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95", event_with_tags.pubkey.first(5)]}).count
    assert_equal ((event_with_tags.pubkey == "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95") ? 2 : 1), Event.by_nostr_filters({"authors" => ["a19f19f63dc65c8053c9"]}).count
    assert_equal 2, Event.by_nostr_filters({"ids" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f", event_with_tags.event_digest.sha256.first(5)]}).count
    assert_equal 1, Event.by_nostr_filters({"ids" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]}).count
    assert_equal 2, Event.by_nostr_filters({"ids" => []}).count
    assert_equal 0, Event.by_nostr_filters({"ids" => ["INVALID"]}).count
    assert_equal 0, Event.by_nostr_filters({"#e" => ["s"]}).count
    assert_equal 1, Event.by_nostr_filters({"#e" => ["b"]}).count
    assert_equal 1, Event.by_nostr_filters({"#p" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]}).count
    assert_equal 0, Event.by_nostr_filters({"#p" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]}).count
  end

  test "PoW difficulty NIP-13" do
    with_pow = JSON.parse(File.read(Rails.root.join("test", "fixtures", "files", "nostr_event_pow.json")))
    event_with_pow = with_pow.merge({
      "created_at" => Time.at(with_pow["created_at"]),
      "digest_and_sig" => [with_pow.delete("id"), with_pow.delete("sig")]
    })

    assert_equal true, Event.new(event_with_pow).valid?
    assert_equal true, @event.valid?
    RELAY_CONFIG.stub(:min_pow, 1) do
      assert_equal true, Event.new(event_with_pow).valid?
      assert_equal false, @event.valid?
    end
  end
end
