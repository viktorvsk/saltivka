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

      it "works for similar tags (exact match)" do
        event = create(:event, kind: 123, tags: [["R", "PAYLOAD"], ["R", "PAYLOAD"]])
        expect(event.searchable_tags.count).to eq(1)
        expect(event.searchable_tags.first.value).to eq("PAYLOAD")
      end

      it "works for similar tags (case insensitive match)" do
        event = create(:event, kind: 123, tags: [["R", "PAYLOAD"], ["R", "payLoaD"]])
        expect(event.searchable_tags.count).to eq(1)
        expect(event.searchable_tags.first.value).to eq("PAYLOAD")
      end

      it "works for similar tags when their keys case different (#r and #R)" do
        event = create(:event, kind: 123, tags: [["R", "PAYLOAD"], ["r", "PAYLOAD"]])
        expect(event.searchable_tags.count).to eq(2)
        expect(event.searchable_tags.first.value).to eq("PAYLOAD")
        expect(event.searchable_tags.second.value).to eq("PAYLOAD")
      end
    end
  end

  describe MemStore do
    describe ".matching_pubsubs_for" do
      it "matches by tags filter" do
        event = create(:event, kind: 123, tags: [["r", "payload"]])
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["#r" => ["payload"]])
        MemStore.subscribe(cid: "C1", sid: "S2", filters: ["#r" => ["one of options is", "payload", "other"]])
        MemStore.subscribe(cid: "C1", sid: "S3", filters: ["#r" => ["paylo"]])
        expect(MemStore.matching_pubsubs_for(event)).to match_array(["C1:S1", "C1:S2"])
      end

      it "matches by tags filter with special characters" do
        event = create(:event, kind: 123, tags: [["r", "#something"]])
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["#r" => ["#something"]])
        expect(MemStore.matching_pubsubs_for(event)).to match_array(["C1:S1"])
      end

      it "matches by tags filter with spaces" do
        event = create(:event, kind: 123, tags: [["r", "some sentence with spaces"]])
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["#r" => ["some sentence with spaces"]])
        expect(MemStore.matching_pubsubs_for(event)).to match_array(["C1:S1"])
      end

      it "matches by tags filter with commas" do
        event = create(:event, kind: 123, tags: [["r", "some sentence, with commas"]])
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["#r" => ["some sentence, with commas"]])
        expect(MemStore.matching_pubsubs_for(event)).to match_array(["C1:S1"])
      end
    end
  end

  describe Event do
    describe ".by_nostr_filters" do
      it "finds events by tag" do
        create(:event, kind: 123, tags: [["r", "payload"]])
        expect(Event.by_nostr_filters({"#r" => ["payload"]}).count).to eq(1)
        expect(Event.by_nostr_filters({"#r" => ["one of options is", "payload", "other"]}).count).to eq(1)
        expect(Event.by_nostr_filters({"#r" => ["paylo"]}).count).to eq(1)
      end
    end
  end
end
