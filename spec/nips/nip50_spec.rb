require "rails_helper"

RSpec.describe("NIP-50") do
  describe Event do
    describe ".by_nostr_filters" do
      context "with 'search' key" do
        let!(:event) { create(:event, kind: 1, content: "Hello everyone!") }
        let!(:other_event) { create(:event, kind: 2) }

        it "performs full-text search" do
          # TODO: add more examples
          expected_to_match = ["Hello how everyone", "m:manual Hell:*", "m:prefix Hell"]
          expected_to_not_match = ["Hell"]

          expect(described_class.by_nostr_filters({})).to match_array([event, other_event])

          expected_to_match.each do |query|
            expect(described_class.by_nostr_filters({search: query})).to match_array([event])
          end

          expected_to_not_match.each do |query|
            expect(described_class.by_nostr_filters({search: query})).to match_array([])
          end
        end

        context "with manual mode" do
          it "handles syntax error" do
            query = "m:manual Hello!"
            expect(described_class.by_nostr_filters({search: query})).to match_array([])
          end
        end

        context "with prefix mode" do
          it "handles syntax error" do
            query = "m:prefix Hello!"
            expect(described_class.by_nostr_filters({search: query})).to match_array([])
          end
        end
      end
    end
  end
end
