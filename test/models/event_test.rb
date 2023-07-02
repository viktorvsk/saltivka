require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "kind detector" do
    kind2_event = build(:event, kind: 2)
    auth_event = build(:event, kind: 22242)
    unknown_event = build(:event, kind: 100_000)
    assert kind2_event.kinda?(:recommend_server)
    assert kind2_event.kinda?(:protocol_reserved)
    assert auth_event.kinda?(:ephemeral)
    assert auth_event.kinda?(:private)
    assert unknown_event.kinda?(:unknown)
  end
end
