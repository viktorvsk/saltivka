require "rails_helper"

RSpec.describe "NIP-40" do
  describe "Deletes event by id" do
    it "deletes the event by id" do
      event = create(:event)
      DeleteExpiredEventNip40.new.perform(event.sha256)
      expect(Event.exists?(event.id)).to be_falsey
    end
  end

  describe "Already expired event is not stored" do
    it "checks that already expired event is not stored" do
      expires_at = 1.day.ago.to_i.to_s
      event = build(:event, kind: 123, tags: [["expiration", expires_at]])
      expect(event).not_to be_valid
      expect(event.errors[:tags]).to include("'expiration' value is in the past #{Time.at(expires_at.to_i).strftime("%c")}")
    end
  end

  describe "Event that expires in the future is put to the queue" do
    it "checks that event that expires in the future is put to the queue" do
      expires_at = 1.day.from_now.to_i.to_s
      event = build(:event, kind: 123, tags: [["expiration", expires_at]])

      expect(DeleteExpiredEventNip40).to receive(:perform_at).with(expires_at, event.sha256)

      expect(event.save).to be_truthy
    end
  end

  describe "Event that has already expired is not put to the queue" do
    it "checks that event that has already expired is not put to the queue" do
      expires_at = 1.day.from_now.to_i.to_s
      event = build(:event, kind: 123, tags: [["expiration", expires_at]])

      expect(DeleteExpiredEventNip40).to receive(:perform_at).with(expires_at, event.sha256)

      expect(event.save).to be_truthy
    end
  end

  describe "Event with invalid expiration tag is not stored" do
    it "checks that event with invalid expiration tag is not stored" do
      event = build(:event, kind: 123, tags: [["expiration", "INVALID"]])
      expect(event).not_to be_valid
      expect(event.errors[:tags]).to include("'expiration' must be unix timestamp")
    end
  end
end
