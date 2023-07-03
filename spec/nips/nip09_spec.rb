require "rails_helper"

RSpec.describe "NIP-09" do
  describe Event do
    context "when it was deleted before" do
      let(:event) { build(:event, kind: 1) }
      let(:delete_event) { create(:event, kind: 5, pubkey: event.pubkey, tags: [["e", event.sha256]]) }
      it "is not saved " do
        delete_event
        expect(DeleteEvent.by_pubkey_and_sha256(event.pubkey, event.sha256)).to exist
        expect(event).to be_invalid
        expect(event.errors[:id]).to include("is already listed as deleted")
      end
    end

    context "with kind 5" do
      let!(:event) { create(:event, kind: 1) }
      it "deletes already saved Event that matches e-tag" do
        expect { create(:event, kind: 5, pubkey: event.pubkey, tags: [["e", event.sha256]]) }.to(change { Event.exists?(event.id) }.from(true).to(false))
      end
      it "does not delete other kind 5 events (undo is not supported)" do
        some_event = build(:event)
        event = create(:event, kind: 5, pubkey: some_event.pubkey, tags: [["e", some_event.sha256]])
        other_event = build(:event, kind: 5, pubkey: event.pubkey, tags: [["e", event.sha256]])

        expect(other_event.save).to be_truthy
        expect(event.reload).to be_persisted
      end
    end

    context "with invalid data" do
      it "requires e-tag" do
        event = build(:event, kind: 5, tags: [["x", build(:event).sha256]])

        expect(event).not_to be_valid
        expect(event.errors[:tags]).to include("must have 'e' entry for kind 5 event (DeleteEvent)")
      end
      it "requires valid pubkey in e-tag" do
        event = build(:event, kind: 5, tags: [["e", "INVALID"]])

        expect(event).not_to be_valid
        expect(event.errors[:tags]).to include("'e' tag must have a valid hex pubkey as a last (and second) element for kind 5 event (DeleteEvent)")
      end
    end
  end
end
