require "rails_helper"

RSpec.describe "NIP-26" do
  describe Event do
    context "with valid delegation-tag" do
      it "passes" do
        parsed_json = JSON.parse(File.read(Rails.root.join(*%w[spec support nostr_event_delegated.json])))
        event_params = parsed_json.merge("sha256" => parsed_json.delete("id"), "created_at" => Time.at(parsed_json["created_at"]))
        event = Event.new(event_params)

        expect(event).to be_valid
      end
      describe SearchableTag do
        it "indexes second value" do
          event = create(:event, :delegated_event, kind: 1, created_at: Time.at(1687949586 - 100))
          expect(event.searchable_tags.count).to eq(1)
          expect(event.searchable_tags.first.value).to eq(NIP_26_TAG[:pk])
        end
      end
    end

    context "with invalid delegation-tag" do
      it "fails to persist" do
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
end
