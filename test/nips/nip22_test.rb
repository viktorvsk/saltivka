require "test_helper"

class Nip22Test < ActiveSupport::TestCase
  test "NewEvent created_at limits" do
    event = build(:event, kind: 1, created_at: 1.day.ago)
    publish_mock = MiniTest::Mock.new
    publish_mock.expect :call, nil, ["events:CONN_ID:_:ok", ["OK", event.sha256, false, "error: Created at must be within limits"].to_json]

    RELAY_CONFIG.stub(:created_at_in_past, 1000) do
      REDIS.stub(:publish, publish_mock) do
        NewEvent.perform_sync("CONN_ID", event.to_json)
      end
    end

    publish_mock.verify
  end
end
