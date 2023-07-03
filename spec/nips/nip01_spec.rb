require "rails_helper"

RSpec.describe("NIP-01") do
  subject { NewSubscription.new }

  it "works with empty filters array" do
    event = create(:event, kind: 123)

    expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", sid: "SUBID", command: :found_event, payload: event.to_json)
    expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", sid: "SUBID", command: :found_end, payload: "EOSE")

    subject.perform("CONN_ID", "SUBID", "[]")
  end

  it "works with filter_set instead of filters" do
    event = create(:event, kind: 0, pubkey: FAKE_CREDENTIALS[:alice][:pk])

    expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", sid: "SUBID", command: :found_event, payload: event.to_json)
    expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", sid: "SUBID", command: :found_end, payload: "EOSE")

    subject.perform("CONN_ID", "SUBID", {kinds: [0], authors: ["a19f19f"]}.to_json)
  end

  it "works with empty filter_set" do
    event = create(:event, kind: 123)

    expect(MemStore).to receive(:fanout).once.with(cid: "CONN_ID", sid: "SUBID", command: :found_event, payload: event.to_json)
    expect(MemStore).to receive(:fanout).once.with(cid: "CONN_ID", sid: "SUBID", command: :found_end, payload: "EOSE")

    subject.perform("CONN_ID", "SUBID", "[{}]")
  end

  it "does nothing when provided JSON is invalid" do
    expect(MemStore).to_not receive(:fanout)
    subject.perform("CONN_ID", "SUBID", "INVALID")
  end

  it "does nothing when provided connection_id is empty" do
    expect(MemStore).to_not receive(:fanout)
    subject.perform("", "", "[]")
  end

  describe "T" do
    let(:sk) { "945e01e37662430162121b804d3645a86d97df9d256917d86735d0eb219393eb" }
    let(:pk) { "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95" }
    let(:sha256) { "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f" }
    let(:sig) { Schnorr.sign([sha256].pack("H*"), [sk].pack("H*")).encode.unpack1("H*") }

    let!(:event) do
      event_params = {
        created_at: Time.at(1687183979),
        kind: 0,
        tags: [],
        content: "",
        sha256: sha256,
        sig: sig,
        pubkey: pk
      }

      Event.create!(event_params)
    end

    it "serializes to nostr format" do
      assert event.persisted?
      expect(Digest::SHA256.hexdigest(JSON.dump(event.to_nostr_serialized))).to eq("bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f")
    end

    it "matches a single event with a filter_set" do
      event_with_tags = create(:event, kind: 1, tags: [["e", "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"], ["p", "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]])

      parsed_json = JSON.parse(File.read(Rails.root.join(*%w[spec support nostr_event_delegated.json])))
      delegated_event_params = parsed_json.merge("sha256" => parsed_json.delete("id"), "created_at" => Time.at(parsed_json["created_at"]))
      delegated_event = Event.new(delegated_event_params)

      assert delegated_event.matches_nostr_filter_set?({"authors" => ["8e0d3d"]})
      assert delegated_event.matches_nostr_filter_set?({"authors" => ["09cd08d"]})

      assert event.matches_nostr_filter_set?({"ids" => ["bf84a73"]})
      assert event.matches_nostr_filter_set?({"authors" => ["a19f19f"]})
      refute event.matches_nostr_filter_set?({"authors" => ["_a19f19f"]})

      assert event_with_tags.matches_nostr_filter_set?({"#e" => ["bf84a"]})
      assert event_with_tags.matches_nostr_filter_set?({"#p" => ["a19f19"]})
      refute event_with_tags.matches_nostr_filter_set?({"#e" => ["a19f19"]})

      assert build(:event, kind: 4).matches_nostr_filter_set?({"kinds" => [4]})
      refute build(:event, kind: 3).matches_nostr_filter_set?({"kinds" => [4]})
      refute build(:event, kind: 4, created_at: 1.hour.ago).matches_nostr_filter_set?({"kinds" => [4], "until" => 2.days.ago.to_i})
      assert build(:event, kind: 4, created_at: 1.day.ago).matches_nostr_filter_set?({"kinds" => [4], "until" => 2.hours.ago.to_i})
      assert build(:event, created_at: 1.hour.ago).matches_nostr_filter_set?({"since" => 2.days.ago.to_i})
      refute build(:event, created_at: 1.day.ago).matches_nostr_filter_set?({"since" => 2.hours.ago.to_i})
    end

    # Here we test a use case where we have implemented a new filter,
    # added it to AVAILABLE FILTERS, but for some reason missed to handle it
    it "handles edge filter" do
      allow(RELAY_CONFIG).to receive(:available_filters).and_return(%w[kinds ids authors #e #p since until edge_filter])
      refute build(:event).matches_nostr_filter_set?({"edge_filter" => 2.hours.ago.to_i})
    end

    it "finds events matching filter_set in the database" do
      event_with_tags = create(:event, kind: 1, tags: [["e", "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"], ["p", "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]])

      parsed_json = JSON.parse(File.read(Rails.root.join(*%w[spec support nostr_event_delegated.json])))
      event_params = parsed_json.merge("sha256" => parsed_json.delete("id"), "created_at" => Time.at(parsed_json["created_at"]))
      Event.create!(event_params)

      expect(Event.by_nostr_filters({"authors" => ["09cd08d"]}).count).to eq(1)
      expect(Event.by_nostr_filters({"authors" => ["8e0d3"]}).count).to eq(1)
      expect(Event.by_nostr_filters({}).count).to eq(3)
      expect(Event.by_nostr_filters({limit: 1}).count).to eq(1)
      expect(Event.by_nostr_filters({kinds: 0}).count).to eq(1)
      expect(Event.by_nostr_filters({"authors" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95", event_with_tags.pubkey.first(5)]}).count).to eq(2)
      expect(Event.by_nostr_filters({"authors" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]}).count).to eq((event_with_tags.pubkey == "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95") ? 2 : 1)
      expect(Event.by_nostr_filters({"ids" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f", event_with_tags.sha256.first(5)]}).count).to eq(2)
      expect(Event.by_nostr_filters({"ids" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]}).count).to eq(1)
      expect(Event.by_nostr_filters({"ids" => []}).count).to eq(3)
      expect(Event.by_nostr_filters({"ids" => ["INVALID"]}).count).to eq(0)
      expect(Event.by_nostr_filters({"#e" => ["s"]}).count).to eq(0)
      expect(Event.by_nostr_filters({"#e" => ["b"]}).count).to eq(1)
      expect(Event.by_nostr_filters({"#p" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]}).count).to eq(1)
      expect(Event.by_nostr_filters({"#p" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]}).count).to eq(0)
    end
  end
end
