require "rails_helper"

RSpec.describe Nostr::Commands::Contracts::Base do
  it "requires to implement #schema" do
    expect { Nostr::Commands::Contracts::Base.new.send(:schema) }.to raise_exception(NotImplementedError)
  end
  it "requires to implement #validate_dependent" do
    expect { Nostr::Commands::Contracts::Base.new.send(:validate_dependent, {}) }.to raise_exception(NotImplementedError)
  end
end
