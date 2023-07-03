require "rails_helper"

RSpec.describe Nostr::Presenters::Errors do
  it "displays JSON" do
    expect(Nostr::Presenters::Errors.new({error_key: "error text"}, "JSON").to_s).to eq({error_key: "error text"}.to_json)
    expect(Nostr::Presenters::Errors.new({error_key: "<>"}, "JSON").to_s).to eq(%({"error_key":"<>"}))
  end
  it "displays TEXT by default" do
    expect(Nostr::Presenters::Errors.new({error_key: "error text"}).to_s).to eq("error text")
    expect(Nostr::Presenters::Errors.new({error_key: "<>"}, "TEXT").to_s).to eq("<>")
  end
end
