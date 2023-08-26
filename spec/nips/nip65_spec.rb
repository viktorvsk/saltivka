require "rails_helper"

RSpec.describe "NIP-65" do
  describe Nostr::RelayController do
    describe "#authorized?" do
      subject do
        result = Nostr::RelayController.new.perform(event_data: @nostr_event) do |notice|
          expect(notice).to eq(["NOTICE", @expected_error].to_json) if @expected_error
        end

        result
      end

      it "works when not authorized but event is exempt" do
        allow(RELAY_CONFIG).to receive(:required_auth_level_for_req).and_return(1)
        allow(Nostr::Nips::Nip65).to receive(:call).and_return(true)
        expect_any_instance_of(Nostr::RelayController).to receive(:req_command)

        @nostr_event = ["REQ", "SUBID", {}].to_json
        subject
      end
    end
  end

  it "allows to exempty only 10002 events" do
    assert(Nostr::Nips::Nip65.call("EVENT", ["EVENT", "SUBID", build(:event, kind: 10002).as_json.stringify_keys]))
    refute(Nostr::Nips::Nip65.call("EVENT", ["EVENT", "SUBID", build(:event, kind: 1000).as_json.stringify_keys]))
    refute(Nostr::Nips::Nip65.call("REQ", ["REQ", {kinds: [1]}.stringify_keys]))
    assert(Nostr::Nips::Nip65.call("REQ", ["REQ", {kinds: [10002]}.stringify_keys]))
    refute(Nostr::Nips::Nip65.call("REQ", ["REQ", {kinds: [0, 10002]}.stringify_keys]))
    refute(Nostr::Nips::Nip65.call("REQ", ["REQ", {kinds: [10002]}.stringify_keys, {kinds: [1]}.stringify_keys]))
  end
end
