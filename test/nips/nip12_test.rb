require "test_helper"

class Nip12Test < ActiveSupport::TestCase
  test "creates SearchableTag association only for the first value" do
    event = create(:event, kind: 123, tags: [["r", "payload", "only first is value is indexed"]])
    assert_equal 1, event.searchable_tags.count
  end

  test "matches event by #r filter" do
    event = create(:event, kind: 123, tags: [["r", "payload"]])
    assert event.matches_nostr_filter_set?({"#r" => ["payload"]})
    assert event.matches_nostr_filter_set?({"#r" => ["one of options is", "payload", "other"]})
    assert event.matches_nostr_filter_set?({"#r" => ["paylo"]})

    assert_equal 1, Event.by_nostr_filters({"#r" => ["payload"]}).count
    assert_equal 1, Event.by_nostr_filters({"#r" => ["one of options is", "payload", "other"]}).count
    assert_equal 1, Event.by_nostr_filters({"#r" => ["paylo"]}).count
  end
end
