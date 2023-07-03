require "rails_helper"

RSpec.describe "NIP-12" do
  describe "creates SearchableTag association only for the first value" do
    it "creates the association" do
      event = create(:event, kind: 123, tags: [["r", "payload", "only first is value is indexed"]])
      expect(event.searchable_tags.count).to eq(1)
    end
  end

  describe "matches event by #r filter" do
    it "matches the event with specific filter values" do
      event = create(:event, kind: 123, tags: [["r", "payload"]])
      assert event.matches_nostr_filter_set?({"#r" => ["payload"]})
      assert event.matches_nostr_filter_set?({"#r" => ["one of options is", "payload", "other"]})
      assert event.matches_nostr_filter_set?({"#r" => ["paylo"]})

      expect(Event.by_nostr_filters({"#r" => ["payload"]}).count).to eq(1)
      expect(Event.by_nostr_filters({"#r" => ["one of options is", "payload", "other"]}).count).to eq(1)
      expect(Event.by_nostr_filters({"#r" => ["paylo"]}).count).to eq(1)
    end
  end
end
