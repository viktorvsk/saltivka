require "test_helper"

class Nip1Test < ActiveSupport::TestCase
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

  test "nostr format serialization" do
    assert true, @event.persisted?
    assert "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f", Digest::SHA256.hexdigest(JSON.dump(@event.to_nostr_serialized))
  end

  test "Single event matching filter_set" do
    event_with_tags = create(:event, kind: 1, tags: [["e", "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"], ["p", "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]])

    parsed_json = JSON.parse(File.read(Rails.root.join(*%w[test fixtures files nostr_event_delegated.json])))
    delegated_event_params = parsed_json.merge("sha256" => parsed_json.delete("id"), "created_at" => Time.at(parsed_json["created_at"]))
    delegated_event = Event.new(delegated_event_params)

    assert delegated_event.matches_nostr_filter_set?({"authors" => ["8e0d3d"]})
    assert delegated_event.matches_nostr_filter_set?({"authors" => ["09cd08d"]})

    assert @event.matches_nostr_filter_set?({"ids" => ["bf84a73"]})
    assert @event.matches_nostr_filter_set?({"authors" => ["a19f19f"]})
    refute @event.matches_nostr_filter_set?({"authors" => ["_a19f19f"]})

    assert event_with_tags.matches_nostr_filter_set?({"#e" => ["bf84a"]})
    assert event_with_tags.matches_nostr_filter_set?({"#p" => ["a19f19"]})
    refute event_with_tags.matches_nostr_filter_set?({"#e" => ["a19f19"]})

    assert build(:event, kind: 4).matches_nostr_filter_set?({"kinds" => [4]})
    refute build(:event, kind: 3).matches_nostr_filter_set?({"kinds" => [4]})
    refute build(:event, kind: 4, created_at: 1.hour.ago).matches_nostr_filter_set?({"kinds" => [4], "until" => 2.days.ago.to_i})
    assert build(:event, kind: 4, created_at: 1.day.ago).matches_nostr_filter_set?({"kinds" => [4], "until" => 2.hour.ago.to_i})
    assert build(:event, created_at: 1.hour.ago).matches_nostr_filter_set?({"since" => 2.days.ago.to_i})
    refute build(:event, created_at: 1.day.ago).matches_nostr_filter_set?({"since" => 2.hour.ago.to_i})
  end

  # Here we test a use case where we have implemented new filter
  # added it to AVAILABLE FILTERS but for some reason missed to handle it
  test "edge filter" do
    RELAY_CONFIG.stub(:available_filters, %w[kinds ids authors #e #p since until edge_filter]) do
      refute build(:event).matches_nostr_filter_set?({"edge_filter" => 2.hour.ago.to_i})
    end
  end

  test "Find Events mathcing filter_set in database" do
    event_with_tags = create(:event, kind: 1, tags: [["e", "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"], ["p", "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]])

    parsed_json = JSON.parse(File.read(Rails.root.join(*%w[test fixtures files nostr_event_delegated.json])))
    event_params = parsed_json.merge("sha256" => parsed_json.delete("id"), "created_at" => Time.at(parsed_json["created_at"]))
    Event.create!(event_params)

    assert_equal 1, Event.by_nostr_filters({"authors" => ["09cd08d"]}).to_a.size
    assert_equal 1, Event.by_nostr_filters({"authors" => ["8e0d3"]}).to_a.size

    assert_equal 3, Event.by_nostr_filters({}).count
    assert_equal 1, Event.by_nostr_filters({limit: 1}).count
    assert_equal 1, Event.by_nostr_filters({kinds: 0}).count
    assert_equal 2, Event.by_nostr_filters({"authors" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95", event_with_tags.pubkey.first(5)]}).count
    assert_equal ((event_with_tags.pubkey == "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95") ? 2 : 1), Event.by_nostr_filters({"authors" => ["a19f19f63dc65c8053c9"]}).count
    assert_equal 2, Event.by_nostr_filters({"ids" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f", event_with_tags.sha256.first(5)]}).count
    assert_equal 1, Event.by_nostr_filters({"ids" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]}).count
    assert_equal 3, Event.by_nostr_filters({"ids" => []}).count
    assert_equal 0, Event.by_nostr_filters({"ids" => ["INVALID"]}).count
    assert_equal 0, Event.by_nostr_filters({"#e" => ["s"]}).count
    assert_equal 1, Event.by_nostr_filters({"#e" => ["b"]}).count
    assert_equal 1, Event.by_nostr_filters({"#p" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]}).count
    assert_equal 0, Event.by_nostr_filters({"#p" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]}).count
  end
end
