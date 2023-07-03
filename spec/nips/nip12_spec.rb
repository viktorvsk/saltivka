require "rails_helper"

RSpec.describe "NIP-12" do
  describe SearchableTag do
    context "given a single letter tag" do
      it "gets created only for the first value" do
        event = create(:event, kind: 123, tags: [["r", "payload", "only first is value is indexed"]])
        expect(event.searchable_tags.count).to eq(1)
        expect(event.searchable_tags.first.value).to eq("payload")
      end
      it "works for upcase letters too" do
        event = create(:event, kind: 123, tags: [["R", "PAYLOAD", "only first is value is indexed"]])
        expect(event.searchable_tags.count).to eq(1)
        expect(event.searchable_tags.first.value).to eq("PAYLOAD")
      end
    end
  end

  describe Event do
    let!(:event) { create(:event, kind: 123, tags: [["r", "payload"]]) }
    describe "#matches_nostr_filter_set?" do
      it "matches events by tag" do
        assert event.matches_nostr_filter_set?({"#r" => ["payload"]})
        assert event.matches_nostr_filter_set?({"#r" => ["one of options is", "payload", "other"]})
        assert event.matches_nostr_filter_set?({"#r" => ["paylo"]})
      end
    end

    describe ".by_nostr_filters" do
      it "finds events by tag" do
        expect(Event.by_nostr_filters({"#r" => ["payload"]}).count).to eq(1)
        expect(Event.by_nostr_filters({"#r" => ["one of options is", "payload", "other"]}).count).to eq(1)
        expect(Event.by_nostr_filters({"#r" => ["paylo"]}).count).to eq(1)
      end
    end
  end
end
