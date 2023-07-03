require "rails_helper"

RSpec.describe("NIP-22") do
  it "NewEvent created_at limits" do
    event = build(:event, kind: 1, created_at: 1.day.ago)

    allow(RELAY_CONFIG).to receive(:created_at_in_past).and_return(1000)
    expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", command: :ok, payload: ["OK", event.sha256, false, "error: Created at must be within limits"].to_json)

    NewEvent.perform_sync("CONN_ID", event.to_json)
  end
end
