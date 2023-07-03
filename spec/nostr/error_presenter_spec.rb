require "rails_helper"

RSpec.describe Nostr::Presenters::Errors do
  it "presents errors in JSON" do
    expect({error_key: "error text"}.to_json).to eq Nostr::Presenters::Errors.new({error_key: "error text"}, "JSON").to_s
    expect(%({"error_key":"<>"})).to eq Nostr::Presenters::Errors.new({error_key: "<>"}, "JSON").to_s
  end
end
