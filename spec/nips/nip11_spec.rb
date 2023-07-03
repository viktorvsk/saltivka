require "rails_helper"

RSpec.describe("NIP-11") do
  describe "Nostr::Relay" do
    it "responds to a non-websocket request" do
      # TODO: test actual values
      expect(Nostr::Relay.call({})).to eq [200, {"Content-Type" => "application/json"}, [Nostr::Nips::Nip11.call.to_json]]
    end
  end
end
