require "rails_helper"

RSpec.describe "NIP-16" do
  describe Event do
    context "given regular event kind" do
      it "persists" do
        kinds = [1000, 9999, rand(1000...10000)]
        events = kinds.map do |k|
          create(:event, kind: k)
        end
        assert events.all?(&:persisted?)
      end
    end
    context "given replaceable event kind" do
      it "deletes other replaceable events and keeps the most recent one" do
        protocol_exceptions_kinds = [0, 3, 41]
        protocol_exceptions_kinds.flatten.each do |k|
          e1 = create(:event, kind: k, pubkey: FAKE_CREDENTIALS[:alice][:pk])
          e2 = create(:event, kind: k, pubkey: FAKE_CREDENTIALS[:alice][:pk])

          assert e2.reload.persisted?
          refute Event.where(id: e1.id).exists?
        end
      end
      it "deletes replaceable events with lower created_at" do
        replaceable_kinds = [rand(10000...20000), 10000, 19999]
        replaceable_kinds.flatten.each do |k|
          e1 = create(:event, kind: k, pubkey: FAKE_CREDENTIALS[:alice][:pk])
          e2 = create(:event, kind: k, pubkey: FAKE_CREDENTIALS[:alice][:pk])

          assert e2.reload.persisted?
          refute Event.where(id: e1.id).exists?
        end
      end
      context "with the same created_at" do
        it "deletes the one with the higher id" do
          e1 = create(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.at(1687970750), content: "Another")
          e2 = build(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.at(1687970750), content: "some")

          assert e2.save
          refute Event.where(id: e1.id).exists?
          assert e2.reload.persisted?
        end

        it "doesn't save the one with the higher id" do
          e1 = create(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.at(1687970750), content: "some")
          e2 = build(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.at(1687970750), content: "Another")

          refute e2.save
          assert e1.reload.persisted?
          assert e2.new_record?
        end
      end
      context "with invalid data" do
        it "doesn't delete existing events" do
          e1 = create(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk])
          e2 = build(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: 1.year.from_now)
          refute e2.save
          assert e1.reload.persisted?
          assert e2.new_record?
        end

        it "doesn't save older replaceable event" do
          e1 = create(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.now)
          e2 = build(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: 1.day.ago)
          refute e2.save
          assert e1.reload.persisted?
          assert e2.new_record?
          expect(e2.errors[:sha256]).to include("has already been taken")
        end
      end
    end

    context "given ephemeral event kind" do
      it "fails to persist" do
        kind = [rand(20000...30000), 20000, 29999].sample
        event = build(:event, kind: kind)

        assert event.kinda?(:ephemeral)
        refute event.save
        expect(event.errors[:kind]).to include("must not be ephemeral")
      end
    end
  end
end
