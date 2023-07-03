require "rails_helper"

RSpec.describe("NIP-20") do
  subject { NewEvent.new }
  it "NewEvent responds with OK" do
    event = build(:event, kind: 555)

    expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", command: :ok, payload: ["OK", event.sha256, true, ""].to_json)

    subject.perform("CONN_ID", event.to_json)
  end

  it "NewEvent given ephemeral event doesn't send OK on success and does not get stored in database" do
    REDIS_TEST_CONNECTION.hset("subscriptions", "CONN_ID:SUBID", "[{\"kinds\": [20000]}]")
    event = build(:event, kind: 20000)

    expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", sid: "SUBID", command: :found_event, payload: event.to_json)

    subject.perform("CONN_ID", event.to_json)
    expect(Event.where(sha256: event.sha256)).to_not be_exists
  end

  it "NewEvent responds with duplicate: OK message" do
    event = create(:event)

    expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", command: :ok, payload: ["OK", event.sha256, false, "duplicate: this event is already present in the database"].to_json)

    subject.perform("CONN_ID", event.to_json)
  end
end
