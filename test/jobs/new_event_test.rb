require "test_helper"

class NewEventTest < ActiveSupport::TestCase
  setup do
  end

  test "basic" do
    REDIS_TEST_CONNECTION.hset("subscriptions", "CONN_ID:SUBID", "[{\"kinds\": [555]}]")
    NewEvent.perform_sync("CONN_ID", build(:event, kind: 555).to_json)
  end
end
