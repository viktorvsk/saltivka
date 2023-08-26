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

      subject.perform("CONN_ID", "SUBID", {kinds: [0], authors: ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]}.to_json)
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

  describe Nostr::RelayController do
    before do
      @random_connection_id = "CONN_ID"
      @valid_event = JSON.dump(JSON.parse(File.read(Rails.root.join("spec", "support", "nostr_event_real.json"))))
    end

    subject do
      allow(SecureRandom).to receive(:hex).and_return(@random_connection_id)
      result = Nostr::RelayController.new.perform(event_data: @nostr_event) do |notice|
        expect(notice).to eq(["NOTICE", "error: #{@expected_error}"].to_json) if @expected_error
      end

      result
    end

    it "pushes event to Sidekiq" do
      @nostr_event = ["COUNT", "SUBID", {}].to_json

      subject

      assert_equal SIDEKIQ_REDIS_TEST_CONNECTION.llen("queue:nostr.nip45"), 1
      assert_equal SIDEKIQ_REDIS_TEST_CONNECTION.lpop("queue:nostr.nip45"), {class: "CountRequest", args: ["CONN_ID", "SUBID", "[{}]"]}.to_json
      assert_equal REDIS_TEST_CONNECTION.smembers("client_reqs:CONN_ID"), []
      # assert_equal REDIS_TEST_CONNECTION.hgetall("subscriptions"), {}
    end
  end
end
