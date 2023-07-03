require "rails_helper"

RSpec.describe ApplicationMailer do
  it "has the correct default 'from' value" do
    expect(ApplicationMailer.default[:from]).to eq("admin@nostr.localhost")
  end
end
