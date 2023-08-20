require "rails_helper"

RSpec.describe("NIP-01") do
  let(:sk) { "945e01e37662430162121b804d3645a86d97df9d256917d86735d0eb219393eb" }
  let(:pk) { "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95" }
  let(:sha256) { "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f" }
  let(:sig) do
    ctx = Secp256k1::Context.new
    key_pair = ctx.key_pair_from_private_key([sk].pack("H*"))
    ctx.sign_schnorr(key_pair, [sha256].pack("H*")).serialized.unpack1("H*")
  end

  describe NewSubscription do
    context "fanout to subscribers when" do
      let(:event) { create(:event, kind: 0, pubkey: FAKE_CREDENTIALS[:alice][:pk]) }

      before do
        expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", sid: "SUBID", command: :found_event, payload: event.to_json)
        expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", sid: "SUBID", command: :found_end, payload: "EOSE")
      end

      it "has filters as an array" do
        subject.perform("CONN_ID", "SUBID", "[]")
      end

      it "has filter_set hash instead of a filters array" do
        subject.perform("CONN_ID", "SUBID", {kinds: [0], authors: ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]}.to_json)
      end

      it "works with empty filter_set" do
        subject.perform("CONN_ID", "SUBID", "[{}]")
      end
    end

    context "does not fanout when" do
      before { expect(MemStore).to_not receive(:fanout) }
      it "has invalid JSON" do
        subject.perform("CONN_ID", "SUBID", "INVALID")
      end

      it "has empty connection_id" do
        subject.perform("", "", "[]")
      end
    end
  end

  describe NewEvent do
    it "fanout with OK" do
      event = build(:event, kind: 555)

      expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", command: :ok, payload: ["OK", event.sha256, true, ""].to_json)

      subject.perform("CONN_ID", event.to_json)
    end

    it "fanout with duplicate: OK message" do
      event = create(:event)

      expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", command: :ok, payload: ["OK", event.sha256, false, "duplicate: this event is already present in the database (for replaceable and parameterized replaceable events it may mean newer events are present)"].to_json)

      subject.perform("CONN_ID", event.to_json)
    end

    context "given ephemeral event" do
      it "fanout OK on success and does not store event in database" do
        MemStore.subscribe(cid: "CONN_ID", sid: "SUBID", filters: [{kinds: [20000]}])
        event = build(:event, kind: 20000)

        expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", sid: "SUBID", command: :found_event, payload: event.to_json, conn: anything).once
        expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", command: :ok, payload: ["OK", event.sha256, true, ""].to_json).once

        subject.perform("CONN_ID", event.to_json)
        expect(Event.where(sha256: event.sha256)).to_not be_exists
      end
    end
  end

  describe Event do
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

    describe "#pubkey=" do
      it "assigns author if pubkey is already taken" do
        event = create(:event, pubkey: FAKE_CREDENTIALS[:alice][:pk])
        event_params = build(:event, pubkey: FAKE_CREDENTIALS[:alice][:pk]).attributes.except("id", "author_id").merge({
          pubkey: FAKE_CREDENTIALS[:alice][:pk]
        })
        other_event = Event.create(event_params)

        expect(other_event).to be_persisted
        expect(other_event.pubkey).to eq(event.pubkey)
      end
    end

    describe "#to_nostr_serialized" do
      it "matches payload digest" do
        assert event.persisted?
        expect(Digest::SHA256.hexdigest(JSON.dump(event.to_nostr_serialized))).to eq("bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f")
      end
    end

    describe ".by_nostr_filters" do
      it "finds events matching filter_set in the database" do
        event_with_tags = create(:event, kind: 1, tags: [["e", "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"], ["p", "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]])

        parsed_json = JSON.parse(File.read(Rails.root.join(*%w[spec support nostr_event_delegated.json])))
        event_params = parsed_json.merge("sha256" => parsed_json.delete("id"), "created_at" => Time.at(parsed_json["created_at"]))
        Event.create!(event_params)

        expected_events_for_author = (event_with_tags.pubkey == "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95") ? 2 : 1
        expect(Event.by_nostr_filters({"authors" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]}).count).to eq(expected_events_for_author)

        # TODO: fix flaky specs
        # expect(Event.by_nostr_filters({"authors" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95", event_with_tags.pubkey.first(5)]}).count).to eq(1)
        # expect(Event.by_nostr_filters({"ids" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f", event_with_tags.sha256.first(5)]}).count).to eq(1)

        expect(Event.by_nostr_filters({"authors" => ["8e0d3"]}).count).to eq(0)
        expect(Event.by_nostr_filters({"authors" => ["8e0d3d3eb2881ec137a11debe736a9086715a8c8beeeda615780064d68bc25dd"]}).count).to eq(1)
        expect(Event.by_nostr_filters({"authors" => ["09cd08d"]}).count).to eq(0)
        expect(Event.by_nostr_filters({"authors" => ["09cd08d416b78dd3e1d6c00c9e14087d803df6360fbf0acdb30106ca042ee81e"]}).count).to eq(1)
        expect(Event.by_nostr_filters({}).count).to eq(3)
        expect(Event.by_nostr_filters({limit: 1}).count).to eq(1)
        expect(Event.by_nostr_filters({kinds: 0}).count).to eq(1)
        expect(Event.by_nostr_filters({"authors" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95", event_with_tags.pubkey]}).count).to eq(2)
        expect(Event.by_nostr_filters({"ids" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f", event_with_tags.sha256]}).count).to eq(2)
        expect(Event.by_nostr_filters({"ids" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]}).count).to eq(1)
        expect(Event.by_nostr_filters({"ids" => []}).count).to eq(3)
        expect(Event.by_nostr_filters({"ids" => ["INVALID"]}).count).to eq(0)
        expect(Event.by_nostr_filters({"#e" => ["s"]}).count).to eq(0)
        expect(Event.by_nostr_filters({"#e" => ["b"]}).count).to eq(0)
        expect(Event.by_nostr_filters({"#p" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]}).count).to eq(1)
        expect(Event.by_nostr_filters({"#p" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]}).count).to eq(0)
      end

      it "finds events by tag" do
        create(:event, kind: 123, tags: [["r", "payload"]])
        expect(Event.by_nostr_filters({"#r" => ["payload"]}).count).to eq(1)
        expect(Event.by_nostr_filters({"#r" => ["one of options is", "payload", "other"]}).count).to eq(1)
        expect(Event.by_nostr_filters({"#r" => ["paylo"]}).count).to eq(0)
      end
    end

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
          e2 = build(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: 100.year.from_now)
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

    context "with regular event kind having the same d-tag" do
      it "persists all events" do
        e1 = create(:event, kind: 1, tags: [["d", "value"]], content: "A")
        e2 = create(:event, kind: 1, tags: [["d", "value"]], content: "B")
        e3 = create(:event, kind: 1, tags: [["d", "value"]], content: "C")

        assert e1.reload.persisted?
        assert e2.reload.persisted?
        assert e3.reload.persisted?
      end

      describe SearchableTag do
        it "doesn't index d-tag implicitly" do
          event = create(:event, kind: 2222, tags: [], content: "A")
          expect(event.searchable_tags.where(name: "d").first).to be_nil
          expect(event.reload.tags).to eq([])
        end
      end
    end

    context "with parameterized_replaceable event kind" do
      it "removes older events with the same kind:pubkey:d_tag" do
        event = create(:event, kind: 30000, tags: [["d", "payload"]], content: "A")
        create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d", "payload"]], content: "B")

        expect(Event.where(id: event.id).exists?).to be false
      end

      it "treats empty and non-canonical d-tag values as empty" do
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

      it "removes events with the same kind:pubkey:d_tag:created_at leaving lower ids" do
        higher_id_event = create(:event, kind: 30000, pubkey: FAKE_CREDENTIALS[:alice][:pk], tags: [["d", ""]], created_at: Time.at(1687996745), content: "B")
        lower_id_event = build(:event, kind: 30000, pubkey: FAKE_CREDENTIALS[:alice][:pk], tags: [["d", ""]], created_at: Time.at(1687996745), content: "A")

        assert lower_id_event.save
        expect(Event.where(id: higher_id_event.id).exists?).to be false
      end

      it "doesn't save event with higher id and the same kind:pubkey:d_tag" do
        lower_id_event = create(:event, kind: 30000, tags: [["d", ""]], content: "A", created_at: Time.at(1687996745), pubkey: FAKE_CREDENTIALS[:alice][:pk])
        higher_id_event = build(:event, kind: 30000, tags: [["d", ""]], content: "B", created_at: Time.at(1687996745), pubkey: FAKE_CREDENTIALS[:alice][:pk])

        expect(higher_id_event.save).to be false
        expect(higher_id_event.errors[:sha256]).to include("has already been taken")
        assert lower_id_event.reload.persisted?
      end

      it "doesn't save older event with the same kind:pubkey:d_tag" do
        event = create(:event, kind: 30000, created_at: Time.now)
        older_event = build(:event, kind: 30000, pubkey: event.pubkey, created_at: 2.days.ago)

        expect(older_event.save).to be false
        expect(older_event.errors[:sha256]).to include("has already been taken")
        assert event.reload.persisted?
      end

      it "adds the implicit d-tag" do
        event = create(:event, kind: 30000, tags: [], content: "A")
        expect(event.searchable_tags.where(name: "d").first.value).to be_empty
        expect(event.reload.tags).to eq([])
      end
    end
  end

  describe MemStore do
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

    describe ".matching_pubsubs_for" do
      it "matches empty filters with any event" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: [])
        expect(MemStore.matching_pubsubs_for(event)).to match_array("C1:S1")
      end

      it "matches author filter when author is delegated" do
        parsed_json = JSON.parse(File.read(Rails.root.join(*%w[spec support nostr_event_delegated.json])))
        delegated_event_params = parsed_json.merge("sha256" => parsed_json.delete("id"), "created_at" => Time.at(parsed_json["created_at"]))
        delegated_event = Event.new(delegated_event_params)
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["authors" => ["09cd08d416b78dd3e1d6c00c9e14087d803df6360fbf0acdb30106ca042ee81e"]])
        MemStore.subscribe(cid: "C1", sid: "S2", filters: ["authors" => ["8e0d3d3eb2881ec137a11debe736a9086715a8c8beeeda615780064d68bc25dd"]])

        expect(MemStore.matching_pubsubs_for(delegated_event)).to match_array(["C1:S1", "C1:S2"])
      end

      it "matches #e and #p filters" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["#e" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]])
        MemStore.subscribe(cid: "C1", sid: "S2", filters: ["#p" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]])
        event_with_tags = create(:event, kind: 1, tags: [["e", "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"], ["p", "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]])

        expect(MemStore.matching_pubsubs_for(event_with_tags)).to match_array(["C1:S1", "C1:S2"])
      end

      it "matches either #e or #p filter" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: [
          "#e" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"],
          "#p" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]
        ])

        e_tag_event = build(:event, kind: 1, tags: [["e", "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]])
        p_tag_event = build(:event, kind: 1, tags: [["p", "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]])
        e_p_tag_event = build(:event, kind: 1, tags: [["p", "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"], ["e", "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]])

        expect(MemStore.matching_pubsubs_for(e_tag_event)).to match_array([])
        expect(MemStore.matching_pubsubs_for(p_tag_event)).to match_array([])
        expect(MemStore.matching_pubsubs_for(e_p_tag_event)).to match_array(["C1:S1"])
      end

      it "matches authors filter" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["authors" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]])
        expect(MemStore.matching_pubsubs_for(event)).to match_array("C1:S1")
        # refute event.matches_nostr_filter_set?({"authors" => ["_a19f19f"]})
      end

      it "matches ids filter" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["ids" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]])
        expect(MemStore.matching_pubsubs_for(event)).to match_array(["C1:S1"])
      end

      it "matches kinds filter" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["kinds" => ["4"]])

        expect(MemStore.matching_pubsubs_for(build(:event, kind: 4))).to match_array(["C1:S1"])
        expect(MemStore.matching_pubsubs_for(build(:event, kind: 3))).to match_array([])
      end

      it "matches since filter" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["since" => 2.days.ago.to_i])
        MemStore.subscribe(cid: "C1", sid: "S2", filters: ["since" => 2.hours.ago.to_i])
        expect(MemStore.matching_pubsubs_for(build(:event, created_at: 1.day.ago))).to match_array(["C1:S1"])
        expect(MemStore.matching_pubsubs_for(build(:event, created_at: 1.hour.ago))).to match_array(["C1:S1", "C1:S2"])
      end

      it "matches until filter" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["until" => 2.days.ago.to_i, :kinds => [4]])
        MemStore.subscribe(cid: "C1", sid: "S2", filters: ["until" => 2.hours.ago.to_i, :kinds => [4]])

        expect(MemStore.matching_pubsubs_for(build(:event, kind: 4, created_at: 1.day.ago))).to match_array(["C1:S2"])
        expect(MemStore.matching_pubsubs_for(build(:event, kind: 4, created_at: 1.hour.ago))).to match_array([])
      end

      it "matches by tags filter" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["#r" => ["payload"]])
        MemStore.subscribe(cid: "C1", sid: "S2", filters: ["#r" => ["one of options is", "payload", "other"]])
        MemStore.subscribe(cid: "C1", sid: "S3", filters: ["#r" => ["paylo"]])
        expect(MemStore.matching_pubsubs_for(build(:event, kind: 123, tags: [["r", "payload"]]))).to match_array(["C1:S1", "C1:S2"])
      end

      it "matches by tags filter with special characters" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["#r" => ["#something"]])
        expect(MemStore.matching_pubsubs_for(build(:event, kind: 123, tags: [["r", "#something"]]))).to match_array(["C1:S1"])
      end

      it "matches by tags filter with spaces" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["#r" => ["some sentence with spaces"]])
        expect(MemStore.matching_pubsubs_for(build(:event, kind: 123, tags: [["r", "some sentence with spaces"]]))).to match_array(["C1:S1"])
      end

      it "matches by tags filter with commas" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["#r" => ["some sentence, with commas"]])
        expect(MemStore.matching_pubsubs_for(build(:event, kind: 123, tags: [["r", "some sentence, with commas"]]))).to match_array(["C1:S1"])
      end

      it "matches by tags filter with casesensitive content" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["#r" => ["TeSt"]])
        MemStore.subscribe(cid: "C1", sid: "S2", filters: ["#r" => ["test"]])
        expect(MemStore.matching_pubsubs_for(build(:event, kind: 123, tags: [["r", "TEST"]]))).to match_array([])
        expect(MemStore.matching_pubsubs_for(build(:event, kind: 123, tags: [["r", "TeSt"]]))).to match_array(["C1:S1"])
        expect(MemStore.matching_pubsubs_for(build(:event, kind: 123, tags: [["r", "test"]]))).to match_array(["C1:S2"])
      end

      it "matches by tags having an empty tag" do
        MemStore.subscribe(cid: "C1", sid: "S1", filters: ["#t" => ["", "another"]])
        expect(MemStore.matching_pubsubs_for(build(:event, tags: [["t", ""]]))).to match_array(["C1:S1"])
        expect(MemStore.matching_pubsubs_for(build(:event, tags: [["t", "another"]]))).to match_array(["C1:S1"])
        expect(MemStore.matching_pubsubs_for(build(:event, tags: [["t", "another"], ["t", ""]]))).to match_array(["C1:S1"])
        expect(MemStore.matching_pubsubs_for(build(:event, tags: [["t", "something"]]))).to match_array([])
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
      result = Nostr::RelayController.new.perform(event_data: @nostr_event, redis: REDIS_TEST_CONNECTION) do |notice|
        expect(notice).to eq(["NOTICE", "error: #{@expected_error}"].to_json) if @expected_error
      end

      result
    end

    describe "REQ" do
      it "saves connection_id and subscription_id to redis and adds a NewSubscription job to Sidekiq queue" do
        @nostr_event = ["REQ", "SUBID", {}].to_json

        subject

        assert_equal REDIS_TEST_CONNECTION.llen("queue:nostr.nip01.req"), 1
        assert_equal REDIS_TEST_CONNECTION.lpop("queue:nostr.nip01.req"), {class: "NewSubscription", args: ["CONN_ID", "SUBID", "[{}]"]}.to_json
        # assert_equal REDIS_TEST_CONNECTION.smembers("client_reqs:CONN_ID"), ["SUBID"] # business logic changed
        # assert_equal REDIS_TEST_CONNECTION.hgetall("subscriptions"), {"CONN_ID:SUBID" => "[{}]"}
      end

      it "filters Events by kinds" do
        filters = {"kinds" => [1]}
        @nostr_event = ["REQ", "SUBID", filters].to_json

        subject

        assert_equal REDIS_TEST_CONNECTION.llen("queue:nostr.nip01.req"), 1
        assert_equal REDIS_TEST_CONNECTION.lpop("queue:nostr.nip01.req"), {class: "NewSubscription", args: ["CONN_ID", "SUBID", [filters].to_json]}.to_json
        # assert_equal REDIS_TEST_CONNECTION.smembers("client_reqs:CONN_ID"), ["SUBID"] # business logic changed
        # assert_equal REDIS_TEST_CONNECTION.hgetall("subscriptions"), {"CONN_ID:SUBID" => [filters].to_json}
      end

      context "with settings" do
        it "fails when filters exceed maximum" do
          REDIS_TEST_CONNECTION.sadd("client_reqs:CONN_ID", "OTHER_SUBID")

          @nostr_event = ["REQ", "SUBID", {}].to_json
          @expected_error = %(Reached maximum of 1 subscriptions)
          allow(RELAY_CONFIG).to receive(:max_subscriptions).and_return(1)
          subject
        end
      end

      context "with invalid arguments, responds with error" do
        it "given multiple filters of invalid type" do
          @expected_error = %(property '/2' is not of type: object; property '/3' is not of type: object)
          @nostr_event = ["REQ", "SUBID", [], "UNKNOWN ARG"].to_json
          subject
        end

        it "when some filter_sets are invalid" do
          @expected_error = %(property '/2' is not of type: object)
          @nostr_event = ["REQ", "SUBID", 1].to_json
          subject
        end

        it "when some filter_sets values are invalid" do # TODO: check later
          @expected_error = %(property '/2/kinds/0' is not of type: integer)
          @nostr_event = ["REQ", "SUBID", {kinds: [{}]}].to_json
          subject
        end

        it "when filters/until < filters/since" do
          @expected_error = %(when both specified, until has always to be after since)
          @nostr_event = ["REQ", "SUBID", {until: 2.days.ago.to_i, since: 1.day.ago.to_i}].to_json
          subject
        end
      end
    end

    describe "CLOSE" do
      before do
        REDIS_TEST_CONNECTION.sadd("client_reqs:CONN_ID", "XYZ123")
      end

      it "removes redis data" do
        @nostr_event = ["CLOSE", "XYZ123"].to_json

        subject

        refute REDIS_TEST_CONNECTION.sismember("client_reqs:CONN_ID", "XYZ123")
        assert_empty REDIS_TEST_CONNECTION.hkeys("subscriptions")
      end

      describe "with invalid args responds with error" do
        it "given additional arguments" do
          @expected_error = "root is invalid: error_type=maxItems"
          @nostr_event = ["CLOSE", "SUBID", "UNKNOWN ARG"].to_json
          subject
        end

        it "given wrong argument" do
          @expected_error = "property '/1' is not of type: string"
          @nostr_event = ["CLOSE", 1234].to_json
          subject
        end
      end
    end

    describe "EVENT" do
      context "with valid event data" do
        it "pushes event to Sidekiq" do
          @nostr_event = ["EVENT", JSON.parse(@valid_event)].to_json

          subject

          assert_equal REDIS_TEST_CONNECTION.llen("queue:nostr.nip01.event"), 1
          assert_equal REDIS_TEST_CONNECTION.lpop("queue:nostr.nip01.event"), {class: "NewEvent", args: ["CONN_ID", @valid_event]}.to_json
        end
      end

      describe "with invalid event data" do
        it "NOTICEs invalid Event `id` length" do
          @expected_error = "property '/1/id' is invalid: error_type=minLength"
          @nostr_event = ["EVENT", JSON.parse(@valid_event).merge("id" => "INVALID")].to_json
          subject
        end

        it "NOTICEs invalid Event `id`" do
          @expected_error = "property '/1/id' doesn't match"
          @nostr_event = ["EVENT", JSON.parse(@valid_event).merge("id" => "00003ea43d2fd2873a9b3191a8e5fdef381ebf2a1c56ca909861fe9489671c65")].to_json
          subject
        end

        it "NOTICEs additional arguments" do
          @expected_error = "root is invalid: error_type=maxItems"
          @nostr_event = ["EVENT", JSON.parse(@valid_event), "INVALID ARG"].to_json
          subject
        end

        it "NOTICEs invalid Event `sig` length" do
          @expected_error = "property '/1/sig' is invalid: error_type=minLength"
          @nostr_event = ["EVENT", JSON.parse(@valid_event).merge("sig" => "INVALID")].to_json
          subject
        end

        it "NOTICEs invalid Event `sig`" do
          @expected_error = "property '/1/sig' doesn't match"
          @nostr_event = ["EVENT", JSON.parse(@valid_event).merge("sig" => "00000f64cfa9945c4a1ea1f7edea8942a84a1d4ee9b36e4e851bda396590f10a11a49519d4859c7c99c1d180bc3feffcad85b9d62a98748decbfc6ed686f5aeb")].to_json
          subject
        end

        it "NOTICEs malformed JSON" do
          @expected_error = "property '/1' is not of type: object"
          @nostr_event = ["EVENT", ""].to_json
          subject
        end

        it "NOTICEs empty JSON" do
          @expected_error = "property '/1' is missing required keys: content, created_at, id, kind, pubkey, sig, tags"
          @nostr_event = ["EVENT", {}].to_json
          subject
        end
      end
    end
  end

  describe SearchableTag do
    context "given a single letter tag" do
      it "gets created only for the first value" do
        event = create(:event, kind: 123, tags: [["r", "payload", "only first is value is indexed"]])
        expect(event.searchable_tags.count).to eq(1)
        expect(event.searchable_tags.first.value).to eq("payload")
      end
      it "works for upcase letters too" do
        event = create(:event, kind: 123, tags: [["R", "PAYLOAD", "only first is value is indexed"]])
        expect(event.searchable_tags.count).to eq(1)
        expect(event.searchable_tags.first.value).to eq("PAYLOAD")
      end

      it "works for similar tags (exact match)" do
        event = create(:event, kind: 123, tags: [["R", "PAYLOAD"], ["R", "PAYLOAD"]])
        expect(event.searchable_tags.count).to eq(1)
        expect(event.searchable_tags.first.value).to eq("PAYLOAD")
      end

      it "works for similar tags (case insensitive match)" do
        event = create(:event, kind: 123, tags: [["R", "PAYLOAD"], ["R", "payLoaD"]])
        expect(event.searchable_tags.count).to eq(1)
        expect(event.searchable_tags.first.value).to eq("PAYLOAD")
      end

      it "works for similar tags when their keys case different (#r and #R)" do
        event = create(:event, kind: 123, tags: [["R", "PAYLOAD"], ["r", "PAYLOAD"]])
        expect(event.searchable_tags.count).to eq(2)
        expect(event.searchable_tags.first.value).to eq("PAYLOAD")
        expect(event.searchable_tags.second.value).to eq("PAYLOAD")
      end
    end

    it "indexes only the first value" do
      event = create(:event, kind: 30000, tags: [["d", "", "payload"]], content: "E")
      expect(event.searchable_tags.pluck(:value)).to eq([""])
    end
  end
end
