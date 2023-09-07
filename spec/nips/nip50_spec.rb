require "rails_helper"

RSpec.describe("NIP-50") do
  describe Event do
    describe ".by_nostr_filters" do
      context "with 'search' filter equal to 'without_tag:x'" do
        it "does not include events with tag 'x'" do
          event = create(:event)
          event_with_x_tag = create(:event, tags: [["x", 100]])
          event_with_capital_x_tag = create(:event, tags: [["X", 200]])

          expect(described_class.by_nostr_filters({search: ["without_tag:x"]})).to match_array([event, event_with_capital_x_tag])
          expect(described_class.by_nostr_filters({search: ["without_tag:x"], "#x": [200]})).to match_array([])
          expect(described_class.by_nostr_filters({search: ["without_tag:x"], "#X": [200]})).to match_array([event_with_capital_x_tag])
          expect(described_class.by_nostr_filters({search: ["without_tag:X"], "#x": [100]})).to match_array([event_with_x_tag])
          expect(described_class.by_nostr_filters({search: ["without_tag:X"], "#X": [300]})).to match_array([])
        end
      end
    end
  end
end
