require "test_helper"

class Nostr::Presenters::ErrorsTest < ActiveSupport::TestCase
  test "presents errors in JSON" do
    assert_equal ({error_key: "error text"}.to_json), Nostr::Presenters::Errors.new({error_key: "error text"}, "JSON").to_s
    assert_equal %({"error_key":"<>"}), Nostr::Presenters::Errors.new({error_key: "<>"}, "JSON").to_s
  end
end
