require "rails_helper"

RSpec.describe("NIP-11") do
  describe "Nostr::Relay" do
    it "responds to a non-websocket request" do
      expected_json = %({"name":"","description":"","pubkey":"","contact":"","supported_nips":[1,2,4,5,9,11,13,15,26,28,40,42,43,45,50,65],"software":"https://github.com/viktorvsk/saltivka","version":null,"limitation":{"max_message_length":16384,"max_subscriptions":20,"max_filters":100,"max_limit":1000,"max_subid_length":64,"max_event_tags":100,"max_content_length":8196,"min_pow_difficulty":0,"auth_required":false,"payment_required":false},"relay_countries":["UK","UA","US"],"language_tags":["en","en-419"],"tags":[],"posting_policy":""})
      response = Nostr::Relay.call({})
      expect(JSON.parse(response.last.first)).to eq(JSON.parse(expected_json))
      expect(response).to match_array [200, {"Content-Type" => "application/json"}, [expected_json]]
    end
  end
end
