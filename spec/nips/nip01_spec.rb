require "rails_helper"

RSpec.describe("NIP-01") do
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
        subject.perform("CONN_ID", "SUBID", {kinds: [0], authors: ["a19f19f"]}.to_json)
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

  describe Event do
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

    describe "#to_nostr_serialized" do
      it "matches payload digest" do
        assert event.persisted?
        expect(Digest::SHA256.hexdigest(JSON.dump(event.to_nostr_serialized))).to eq("bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f")
      end
    end

    describe "#matches_nostr_filter_set?" do
      it "verifies a single event against a given filter_set" do
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
      it "does not match an event if filter is not implemented" do
        allow(RELAY_CONFIG).to receive(:available_filters).and_return(%w[kinds ids authors #e #p since until edge_filter])
        refute build(:event).matches_nostr_filter_set?({"edge_filter" => 2.hours.ago.to_i})
      end
    end

    describe ".by_nostr_filters" do
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

        assert_equal REDIS_TEST_CONNECTION.llen("queue:nostr"), 1
        assert_equal REDIS_TEST_CONNECTION.lpop("queue:nostr"), {class: "NewSubscription", args: ["CONN_ID", "SUBID", "[{}]"]}.to_json
        assert_equal REDIS_TEST_CONNECTION.smembers("client_reqs:CONN_ID"), ["SUBID"]
        assert_equal REDIS_TEST_CONNECTION.hgetall("subscriptions"), {"CONN_ID:SUBID" => "[{}]"}
      end

      it "filters Events by kinds" do
        filters = {"kinds" => [1]}
        @nostr_event = ["REQ", "SUBID", filters].to_json

        subject

        assert_equal REDIS_TEST_CONNECTION.llen("queue:nostr"), 1
        assert_equal REDIS_TEST_CONNECTION.lpop("queue:nostr"), {class: "NewSubscription", args: ["CONN_ID", "SUBID", [filters].to_json]}.to_json
        assert_equal REDIS_TEST_CONNECTION.smembers("client_reqs:CONN_ID"), ["SUBID"]
        assert_equal REDIS_TEST_CONNECTION.hgetall("subscriptions"), {"CONN_ID:SUBID" => [filters].to_json}
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
          @expected_error = %(property '/1' is not of type: object; property '/2' is not of type: object)
          @nostr_event = ["REQ", "SUBID", [], "UNKNOWN ARG"].to_json
          subject
        end

        it "when some filter_sets are invalid" do
          @expected_error = %(property '/1' is not of type: object)
          @nostr_event = ["REQ", "SUBID", 1].to_json
          subject
        end

        it "when some filter_sets values are invalid" do
          @expected_error = %(property '/1/kinds/0' is not of type: integer)
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

        assert_nil REDIS_TEST_CONNECTION.get("client_reqs:CONN_ID")
        assert_empty REDIS_TEST_CONNECTION.hkeys("subscriptions")
      end

      describe "with invalid args responds with error" do
        it "given additional arguments" do
          @expected_error = "root is invalid: error_type=maxItems"
          @nostr_event = ["CLOSE", "SUBID", "UNKNOWN ARG"].to_json
          subject
        end

        it "given wrong argument" do
          @expected_error = "property '/0' is not of type: string"
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

          assert_equal REDIS_TEST_CONNECTION.llen("queue:nostr"), 1
          assert_equal REDIS_TEST_CONNECTION.lpop("queue:nostr"), {class: "NewEvent", args: ["CONN_ID", @valid_event]}.to_json
        end
      end

      describe "with invalid event data" do
        it "NOTICEs invalid Event `id` length" do
          @expected_error = "property '/0/id' is invalid: error_type=minLength"
          @nostr_event = ["EVENT", JSON.parse(@valid_event).merge("id" => "INVALID")].to_json
          subject
        end

        it "NOTICEs invalid Event `id`" do
          @expected_error = "property '/0/id' doesn't match"
          @nostr_event = ["EVENT", JSON.parse(@valid_event).merge("id" => "00003ea43d2fd2873a9b3191a8e5fdef381ebf2a1c56ca909861fe9489671c65")].to_json
          subject
        end

        it "NOTICEs additional arguments" do
          @expected_error = "root is invalid: error_type=maxItems"
          @nostr_event = ["EVENT", JSON.parse(@valid_event), "INVALID ARG"].to_json
          subject
        end

        it "NOTICEs invalid Event `sig` length" do
          @expected_error = "property '/0/sig' is invalid: error_type=minLength"
          @nostr_event = ["EVENT", JSON.parse(@valid_event).merge("sig" => "INVALID")].to_json
          subject
        end

        it "NOTICEs invalid Event `sig`" do
          @expected_error = "property '/0/sig' doesn't match"
          @nostr_event = ["EVENT", JSON.parse(@valid_event).merge("sig" => "00000f64cfa9945c4a1ea1f7edea8942a84a1d4ee9b36e4e851bda396590f10a11a49519d4859c7c99c1d180bc3feffcad85b9d62a98748decbfc6ed686f5aeb")].to_json
          subject
        end

        it "NOTICEs malformed JSON" do
          @expected_error = "property '/0' is not of type: object"
          @nostr_event = ["EVENT", ""].to_json
          subject
        end

        it "NOTICEs empty JSON" do
          @expected_error = "property '/0' is missing required keys: content, created_at, id, kind, pubkey, sig, tags"
          @nostr_event = ["EVENT", {}].to_json
          subject
        end
      end
    end
  end
end
