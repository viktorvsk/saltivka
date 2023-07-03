require "rails_helper"

RSpec.describe "NIP-26" do
  describe "Valid delegation event" do
    it "is valid" do
      parsed_json = JSON.parse(File.read(Rails.root.join(*%w[spec support nostr_event_delegated.json])))
      event_params = parsed_json.merge("sha256" => parsed_json.delete("id"), "created_at" => Time.at(parsed_json["created_at"]))
      event = Event.new(event_params)

      expect(event).to be_valid
    end
  end

  describe "Invalid delegation" do
    it "is invalid for various scenarios" do
      too_old_event = build(:event, :delegated_event, kind: 1, created_at: 1.year.ago)
      too_new_event = build(:event, :delegated_event, kind: 1, created_at: 1.day.from_now)
      invalid_kind_event = build(:event, :delegated_event, kind: 1001, created_at: 1.day.ago)
      invalid_delegation_pubkey_event = build(:event, tags: [["delegation", "INVALID", "", ""]])

      expect(too_old_event).not_to be_valid
      expect(too_new_event).not_to be_valid
      expect(invalid_kind_event).not_to be_valid
      expect(invalid_delegation_pubkey_event).not_to be_valid

      expect(too_old_event.errors[:tags]).to include(%('delegation' created_at < event created_at minimum))
      expect(too_new_event.errors[:tags]).to include(%('delegation' created_at > event created_at maximum))
      expect(invalid_kind_event.errors[:tags]).to include(%('delegation' kind doesn't allow kind 1001))
      expect(invalid_delegation_pubkey_event.errors[:tags]).to include(%('delegation' pubkey must be a valid 64 characters hex))
    end
  end
end
