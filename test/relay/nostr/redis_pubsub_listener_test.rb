require "test_helper"

class RedisPubsubListenerTest < ActiveSupport::TestCase
  test "presents errors in JSON" do
    service = RedisPubsubListener.new(proc {})
    assert_equal false, service.redis.subscribed?
    service.add_channel("CONN_ID:CH1")
    sleep(0.01)
    assert_equal true, service.redis.subscribed?
    service.remove_channel("CONN_ID:CH1")
    sleep(0.01)
    assert_equal false, service.redis.subscribed?
    service.add_channel("CONN_ID:CH2")
    sleep(0.01)
    assert_equal true, service.redis.subscribed?
  end

  test "calls server events handler" do
    test_value = 100
    server_events_handler_mock = proc { test_value += 1 }
    service = RedisPubsubListener.new(server_events_handler_mock)
    service.add_channel("CONN_ID:CH3")
    sleep(0.1)
    assert_equal 100, test_value
    REDIS_TEST_CONNECTION.publish("events:CONN_ID:CH3", "TEST")
    assert_equal 100, test_value
    sleep(0.01)
    assert_equal 101, test_value
  end
end
