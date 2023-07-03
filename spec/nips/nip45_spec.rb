require "rails_helper"

RSpec.describe("NIP-45") do
  describe CountRequest do
    it "fanout with empty filters array" do
      create(:event, kind: 123)
      expect(MemStore).to receive(:pubkey_for).once.with(cid: "CONN_ID")
      expect(MemStore).to receive(:fanout).once.with(cid: "CONN_ID", sid: "SUBID", command: :count, payload: "1")

      subject.perform("CONN_ID", "SUBID", "[]")
    end

    it "fanout with filter_set instead of filters" do
      create(:event, kind: 0, pubkey: FAKE_CREDENTIALS[:alice][:pk])
      expect(MemStore).to receive(:pubkey_for).once.with(cid: "CONN_ID")
      expect(MemStore).to receive(:fanout).once.with(cid: "CONN_ID", sid: "SUBID", command: :count, payload: "1")

      subject.perform("CONN_ID", "SUBID", {kinds: [0], authors: ["a19f19f"]}.to_json)
    end

    it "fanout with empty filter_set" do
      create(:event, kind: 123)
      expect(MemStore).to receive(:pubkey_for).once.with(cid: "CONN_ID")
      expect(MemStore).to receive(:fanout).once.with(cid: "CONN_ID", sid: "SUBID", command: :count, payload: "1")

      subject.perform("CONN_ID", "SUBID", "[{}]")
    end

    context "with invalid arguments" do
      it "does not fanout when provided JSON is invalid" do
        create(:event, kind: 123)
        expect(MemStore).to_not receive(:pubkey_for)
        expect(MemStore).to_not receive(:fanout)

        subject.perform("CONN_ID", "SUBID", "INVALID")
      end

      it "does not fanout when provided connection_id is empty" do
        create(:event, kind: 123)
        expect(MemStore).to_not receive(:pubkey_for)
        expect(MemStore).to_not receive(:fanout)

        subject.perform("", "", "[]")
      end
    end
  end
end
