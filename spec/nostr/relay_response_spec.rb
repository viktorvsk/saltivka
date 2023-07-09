require "rails_helper"

RSpec.describe Nostr::RelayResponse do
  it "handles EOSE" do
    expect(subject.call("FOUND_END", "subid", "EOSE")).to eq(["EOSE", "subid"].to_json)
  end

  it "handles OK" do
    event = create(:event)
    expect(subject.call("OK", "subid", ["OK", event].to_json)).to eq(["OK", event].to_json)
  end

  it "handles COUNT" do
    create(:event, kind: 123, content: "a")
    create(:event, kind: 123, content: "b")

    expect(subject.call("COUNT", "subid", "2")).to eq(["COUNT", "subid", {count: 2}].to_json)
  end

  it "handles EVENT" do
    expect(subject.call("FOUND_EVENT", "SUBID", {id: "HEX"}.to_json)).to eq(["EVENT", "SUBID", {id: "HEX"}].to_json)
  end

  it "handles NOTICE" do
    expect(subject.call("NOTICE", "CONN_ID", "message")).to eq(["NOTICE", "message"].to_json)
  end

  it "does not handle TERMINATE" do
    expect(subject.call("TERMINATE", "CONN_ID", [3403, "blocked"].to_json)).to be_nil
  end
end
