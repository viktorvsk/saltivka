require "test_helper"

class Nostr::Commands::Contracts::BaseTest < ActiveSupport::TestCase
  test "requires to implement #schema" do
    assert_raise NotImplementedError do
      Nostr::Commands::Contracts::Base.new.send(:schema)
    end
  end
  test "requires to implement #validate_dependent" do
    assert_raise NotImplementedError do
      Nostr::Commands::Contracts::Base.new.send(:validate_dependent, {})
    end
  end
end
