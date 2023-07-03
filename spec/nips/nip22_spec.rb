require "rails_helper"

RSpec.describe("NIP-22") do
  describe NewEvent do
    context "with created_at limits config" do
      before { allow(RELAY_CONFIG).to receive(:created_at_in_past).and_return(1000) }
      it "fanout OK with error" do
        event = build(:event, kind: 1, created_at: 1.day.ago)

        expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", command: :ok, payload: ["OK", event.sha256, false, "error: Created at must be within limits"].to_json)

        subject.perform("CONN_ID", event.to_json)
      end
    end
  end
end
