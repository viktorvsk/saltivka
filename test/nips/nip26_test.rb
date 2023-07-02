require "test_helper"

class Nip26Test < ActiveSupport::TestCase
  test "Valid delegation event" do
    parsed_json = JSON.parse(File.read(Rails.root.join(*%w[test fixtures files nostr_event_delegated.json])))
    event_params = parsed_json.merge("sha256" => parsed_json.delete("id"), "created_at" => Time.at(parsed_json["created_at"]))
    event = Event.new(event_params)

    assert event.valid?
  end

  test "Invalid delegation" do
    too_old_event = build(:event, :delegated_event, kind: 1, created_at: 1.year.ago)
    too_new_event = build(:event, :delegated_event, kind: 1, created_at: 1.day.from_now)
    invalid_kind_event = build(:event, :delegated_event, kind: 1001, created_at: 1.day.ago)
    invalid_delegation_pubkey_event = build(:event, tags: [["delegation", "INVALID", "", ""]])

    refute too_old_event.valid?
    refute too_new_event.valid?
    refute invalid_kind_event.valid?
    refute invalid_delegation_pubkey_event.valid?

    assert_includes too_old_event.errors[:tags], %('delegation' created_at < event created_at minimum)
    assert_includes too_new_event.errors[:tags], %('delegation' created_at > event created_at maximum)
    assert_includes invalid_kind_event.errors[:tags], %('delegation' kind doesn't allow kind 1001)
    assert_includes invalid_delegation_pubkey_event.errors[:tags], %('delegation' pubkey must be a valid 64 characters hex)
  end
end
