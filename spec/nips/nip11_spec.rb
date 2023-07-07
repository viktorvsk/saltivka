require "rails_helper"

RSpec.describe("NIP-11") do
  describe "Nostr::Relay" do
    it "responds to a non-websocket request" do
      expected_json = "{\"name\":\"\",\"description\":\"\",\"pubkey\":\"\",\"contact\":\"\",\"supported_nips\":[1,4,9,11,13,16,20,22,26,28,33,40,42,43,45,65],\"software\":\"\",\"version\":\"\",\"limitation\":{\"max_message_length\":16384,\"max_subscriptions\":20,\"max_filters\":100,\"max_limit\":1000,\"max_subid_length\":64,\"min_prefix\":4,\"max_event_tags\":100,\"max_content_length\":8196,\"min_pow_difficulty\":0,\"auth_required\":false,\"payment_required\":false},\"relay_countries\":[\"UK\",\"UA\",\"US\"],\"language_tags\":[\"en\",\"en-419\"],\"tags\":[],\"posting_policy\":\"\"}"
      expect(Nostr::Relay.call({})).to eq [200, {"Content-Type" => "application/json"}, [expected_json]]
    end
  end
end
