require "rails_helper"

RSpec.describe("NIP-04") do
  describe NewEvent do
    context "with kind 4" do
      it "is not fanout without matching pubkey" do
        event = build(:event, kind: 4, tags: [["p", FAKE_CREDENTIALS[:alice][:pk]]])
        REDIS_TEST_CONNECTION.hset("subscriptions", "CONN_ID:SUBID", [{kind: 4}].to_json)

        expect(MemStore).to receive(:fanout).once.with(cid: "CONN_ID", command: :ok, payload: ["OK", event.sha256, true, ""].to_json)
        subject.perform("CONN_ID", event.to_json)
      end

      it "is not fanout if no p-tag present" do
        event = build(:event, kind: 4)
        REDIS_TEST_CONNECTION.hset("subscriptions", "CONN_ID:SUBID", [{kind: 4}].to_json)

        expect(MemStore).to receive(:fanout).once.with(cid: "CONN_ID", command: :ok, payload: ["OK", event.sha256, true, ""].to_json)
        subject.perform("CONN_ID", event.to_json)
      end

      it "is not fanout to valid subscribers without matching filters" do
        event = build(:event, kind: 4, tags: [["p", FAKE_CREDENTIALS[:alice][:pk]]])
        REDIS_TEST_CONNECTION.hset("subscriptions", "CONN_ID:SUBID", [{kinds: [1]}].to_json)
        REDIS_TEST_CONNECTION.hset("authentications", "CONN_ID", FAKE_CREDENTIALS[:alice][:pk])

        expect(MemStore).to receive(:fanout).once.with(cid: "CONN_ID", command: :ok, payload: ["OK", event.sha256, true, ""].to_json)

        subject.perform("CONN_ID", event.to_json)
      end

      it "is only fanout for matching pubkey with matching filters" do
        event = build(:event, kind: 4, tags: [["p", FAKE_CREDENTIALS[:alice][:pk]]])
        REDIS_TEST_CONNECTION.hset("subscriptions", "CONN_ID:SUBID", [{kind: 4}].to_json)
        REDIS_TEST_CONNECTION.hset("authentications", "CONN_ID", FAKE_CREDENTIALS[:alice][:pk])

        expect(MemStore).to receive(:fanout).once.with(cid: "CONN_ID", sid: "SUBID", command: :found_event, payload: event.to_json)
        expect(MemStore).to receive(:fanout).once.with(cid: "CONN_ID", command: :ok, payload: ["OK", event.sha256, true, ""].to_json)

        subject.perform("CONN_ID", event.to_json)
      end
    end
  end

  describe Event do
    describe ".by_nostr_filters" do
      it "finds kind 4 events by p-tag and author" do
        e1 = create(:event, kind: 4, pubkey: FAKE_CREDENTIALS[:alice][:pk])
        e2 = create(:event, kind: 4, tags: [["p", FAKE_CREDENTIALS[:alice][:pk]]])
        create(:event, kind: 4, pubkey: FAKE_CREDENTIALS[:bob][:pk], tags: [["p", FAKE_CREDENTIALS[:bob][:pk]]])

        expect(Event.by_nostr_filters({kinds: [4]}, FAKE_CREDENTIALS[:alice][:pk]).to_a.map(&:id).sort).to eq([e1.id, e2.id].sort)
      end

      it "finds kind 4 events by delegation" do
        tags = [
          ["p", FAKE_CREDENTIALS[:alice][:pk]],
          ["delegation", FAKE_CREDENTIALS[:carl][:pk], "kind=4", "b05bd5636223b546d2a5f0f5875c2558647558ed94df5378ae34ac053c5cd7d40d524b1c763b7cda096eb8da0cd4ff744cd0946e895c39ea54727cb26257df1e"]
        ]
        e1 = create(:event, kind: 4, pubkey: FAKE_CREDENTIALS[:bob][:pk], tags: tags, created_at: Time.at(1688051860))
        create(:event, kind: 1, pubkey: FAKE_CREDENTIALS[:alice][:pk])
        create(:event, kind: 4, pubkey: FAKE_CREDENTIALS[:alice][:pk])

        expect(Event.by_nostr_filters({kinds: [4]}, FAKE_CREDENTIALS[:carl][:pk]).to_a.map(&:id)).to eq([e1.id])
      end

      it "finds kind 4 events by p-tag, author, and delegation" do
        e1 = create(:event, kind: 4, pubkey: FAKE_CREDENTIALS[:alice][:pk])
        e2 = create(:event, kind: 4, tags: [["p", FAKE_CREDENTIALS[:alice][:pk]]])
        e3 = create(:event, kind: 1)
        create(:event, kind: 4, pubkey: FAKE_CREDENTIALS[:bob][:pk], tags: [["p", FAKE_CREDENTIALS[:bob][:pk]]])

        expect(Event.by_nostr_filters({kinds: [1, 4]}, FAKE_CREDENTIALS[:alice][:pk]).to_a.map(&:id).sort).to eq([e1.id, e2.id, e3.id].sort)
      end

      context "without pubkey argument" do
        it "does not find kind 4 events by default but finds other kinds" do
          e1 = create(:event, kind: 1)
          create(:event, kind: 4)

          expect(Event.by_nostr_filters({kinds: [1, 4]}).to_a.map(&:id)).to eq([e1.id])
        end

        it "does not find kind 4 events by default" do
          create(:event, kind: 4)

          expect(Event.by_nostr_filters({}).to_a).to be_empty
        end
      end
    end
  end
end
