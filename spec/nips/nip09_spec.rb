require "rails_helper"

RSpec.describe "NIP-9" do
  describe "Event of kind 5 deletes proper saved Event" do
    it "deletes the proper saved Event" do
      event = create(:event, kind: 1)
      create(:event, kind: 5, pubkey: event.pubkey, tags: [["e", event.sha256]])

      expect(Event.exists?(event.id)).to be_falsey
    end
  end

  describe "Deleted event (pubkey+id) are not saved" do
    it "checks that deleted event (pubkey+id) is not saved" do
      event = build(:event, kind: 1)
      create(:event, kind: 5, pubkey: event.pubkey, tags: [["e", event.sha256]])

      expect(DeleteEvent.by_pubkey_and_sha256(event.pubkey, event.sha256)).to exist
      expect(event).to be_invalid
      expect(event.errors[:id]).to include("is already listed as deleted")
    end
  end

  describe "kind 5 event without valid pubkey in e tag doesn't save" do
    it "checks that kind 5 event without valid pubkey in e tag is not saved" do
      event = build(:event, kind: 5, tags: [["e", "INVALID"]])

      expect(event).not_to be_valid
      expect(event.errors[:tags]).to include("'e' tag must have a valid hex pubkey as a last (and second) element for kind 5 event (DeleteEvent)")
    end
  end

  describe "kind 5 event without e tag doesn't save" do
    it "checks that kind 5 event without e tag is not saved" do
      event = build(:event, kind: 5, tags: [["x", build(:event).sha256]])

      expect(event).not_to be_valid
      expect(event.errors[:tags]).to include("must have 'e' entry for kind 5 event (DeleteEvent)")
    end
  end

  describe "does not delete kind 5 events since there is no support for undo delete" do
    it "checks that kind 5 events are not deleted" do
      some_event = build(:event)
      event = create(:event, kind: 5, pubkey: some_event.pubkey, tags: [["e", some_event.sha256]])
      other_event = build(:event, kind: 5, pubkey: event.pubkey, tags: [["e", event.sha256]])

      expect(other_event.save).to be_truthy
      expect(event.reload).to be_persisted
    end
  end
end
