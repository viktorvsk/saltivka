require "rails_helper"

RSpec.describe(Event) do
  let(:kind2_event) { build(:event, kind: 2) }
  let(:auth_event) { build(:event, kind: 22242) }
  let(:unknown_event) { build(:event, kind: 100_000) }

  it "detects kind correctly" do
    assert kind2_event.kinda?(:recommend_server)
    assert kind2_event.kinda?(:protocol_reserved)
    assert auth_event.kinda?(:ephemeral)
    assert auth_event.kinda?(:private)
    assert unknown_event.kinda?(:unknown)
  end
end
