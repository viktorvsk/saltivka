require "rails_helper"

RSpec.describe "NIP-33" do
  describe "works for parameterized_replaceable events kinds" do
    it "creates multiple events" do
      e1 = create(:event, kind: 1, tags: [["d", "value"]], content: "A")
      e2 = create(:event, kind: 1, tags: [["d", "value"]], content: "B")
      e3 = create(:event, kind: 1, tags: [["d", "value"]], content: "C")

      assert e1.reload.persisted?
      assert e2.reload.persisted?
      assert e3.reload.persisted?
    end
  end

  describe "removes older events with the same kind:pubkey:d_tag" do
    it "removes older events" do
      event = create(:event, kind: 30000, tags: [["d", "payload"]], content: "A")
      create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d", "payload"]], content: "B")

      expect(Event.where(id: event.id).exists?).to be false
    end
  end

  describe "treats empty and non-canonical d-tag values as empty" do
    it "removes events with empty d-tag value" do
      event = create(:event, kind: 30000, tags: [["d", ""]], content: "A")

      event2 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d", ""]], content: "B")
      expect(Event.where(id: event.id).exists?).to be false

      event3 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d"]], content: "C")
      expect(Event.where(id: event2.id).exists?).to be false

      event4 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [], content: "D")
      expect(Event.where(id: event3.id).exists?).to be false

      event5 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d", "", "payload"]], content: "E")
      expect(Event.where(id: event4.id).exists?).to be false

      event6 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d", ""], ["d", "payload"]], content: "F")
      expect(Event.where(id: event5.id).exists?).to be false

      event7 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d"], ["d", "payload"]], content: "G")
      expect(Event.where(id: event6.id).exists?).to be false

      event8 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d", "", "payload"]], content: "H")
      expect(Event.where(id: event7.id).exists?).to be false

      create(:event, kind: 30000, pubkey: event.pubkey, tags: [["e"]], content: "K")
      expect(Event.where(id: event8.id).exists?).to be false
    end
  end

  describe "removes events with the same kind:pubkey:d_tag:created_at leaving lower ids" do
    it "removes events with higher ids" do
      higher_id_event = create(:event, kind: 30000, pubkey: FAKE_CREDENTIALS[:alice][:pk], tags: [["d", ""]], created_at: Time.at(1687996745), content: "B")
      lower_id_event = build(:event, kind: 30000, pubkey: FAKE_CREDENTIALS[:alice][:pk], tags: [["d", ""]], created_at: Time.at(1687996745), content: "A")

      assert lower_id_event.save
      expect(Event.where(id: higher_id_event.id).exists?).to be false
    end
  end

  describe "doesn't save event with higher id and the same kind:pubkey:d_tag" do
    it "doesn't save the event" do
      lower_id_event = create(:event, kind: 30000, tags: [["d", ""]], content: "A", created_at: Time.at(1687996745), pubkey: FAKE_CREDENTIALS[:alice][:pk])
      higher_id_event = build(:event, kind: 30000, tags: [["d", ""]], content: "B", created_at: Time.at(1687996745), pubkey: FAKE_CREDENTIALS[:alice][:pk])

      expect(higher_id_event.save).to be false
      expect(higher_id_event.errors[:sha256]).to include("has already been taken")
      assert lower_id_event.reload.persisted?
    end
  end

  describe "doesn't save older event with the same kind:pubkey:d_tag" do
    it "doesn't save the older event" do
      event = create(:event, kind: 30000, created_at: Time.now)
      older_event = build(:event, kind: 30000, pubkey: event.pubkey, created_at: 2.days.ago)

      expect(older_event.save).to be false
      expect(older_event.errors[:sha256]).to include("has already been taken")
      assert event.reload.persisted?
    end
  end

  describe "implicit d-tag is added to Event#searchable_tags of parameterized_replaceable kind" do
    it "adds the implicit d-tag" do
      event = create(:event, kind: 30000, tags: [], content: "A")
      expect(event.searchable_tags.where(name: "d").first.value).to be_empty
      expect(event.reload.tags).to eq([])
    end
  end

  describe "implicit d-tag is not added to Event#searchable_tags of regular kind" do
    it "doesn't add the implicit d-tag" do
      event = create(:event, kind: 2222, tags: [], content: "A")
      expect(event.searchable_tags.where(name: "d").first).to be_nil
      expect(event.reload.tags).to eq([])
    end
  end

  describe "only the first value is indexed" do
    it "indexes only the first value" do
      event = create(:event, kind: 30000, tags: [["d", "", "payload"]], content: "E")
      expect(event.searchable_tags.pluck(:value)).to eq([""])
    end
  end
end
