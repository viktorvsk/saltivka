require "test_helper"

class Nip9Test < ActiveSupport::TestCase
  test "Event of kind 5 deletes proper saved Event" do
    event = create(:event, kind: 1)
    create(:event, kind: 5, pubkey: event.pubkey, tags: [["e", event.sha256]])

    refute Event.where(id: event.id).exists?
  end

  test "Deleted event (pubkey+id) are not saved" do
    event = build(:event, kind: 1)
    create(:event, kind: 5, pubkey: event.pubkey, tags: [["e", event.sha256]])

    assert DeleteEvent.by_pubkey_and_sha256(event.pubkey, event.sha256).exists?
    refute event.valid?
    assert_includes event.errors[:id], "is already listed as deleted"
  end

  test "kind 5 event without valid pubkey in e tag doesn't save" do
    event = build(:event, kind: 5, tags: [["e", "INVALID"]])

    refute event.save
    assert_includes event.errors[:tags], "'e' tag must have a valid hex pubkey as a last (and second) element for kind 5 event (DeleteEvent)"
  end

  test "kind 5 event without e tag doesn't save" do
    event = build(:event, kind: 5, tags: [["x", build(:event).sha256]])

    refute event.save
    assert_includes event.errors[:tags], "must have 'e' entry for kind 5 event (DeleteEvent)"
  end

  test "does not delete kind 5 events since there is no support for undo delete" do
    some_event = build(:event)
    event = create(:event, kind: 5, pubkey: some_event.pubkey, tags: [["e", some_event.sha256]])
    other_event = build(:event, kind: 5, pubkey: event.pubkey, tags: [["e", event.sha256]])
    assert other_event.save
    assert event.reload.persisted?
  end
end
