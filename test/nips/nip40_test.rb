require "test_helper"

class Nip40Test < ActiveSupport::TestCase
  test "Deletes event by id" do
    event = create(:event)
    DeleteExpiredEventNip40.new.perform(event.sha256)
    refute Event.where(id: event.id).exists?
  end

  test "Already expired event is not stored" do
    expires_at = 1.day.ago.to_i.to_s
    event = build(:event, kind: 123, tags: [["expiration", expires_at]])
    refute event.save
    assert_includes event.errors[:tags], "'expiration' value is in the past #{Time.at(expires_at.to_i).strftime("%c")}"
  end

  test "Event that expires in future is put to the queue" do
    expires_at = 1.day.from_now.to_i.to_s
    event = build(:event, kind: 123, tags: [["expiration", expires_at]])

    worker_mock = Minitest::Mock.new
    worker_mock.expect :call, nil, [expires_at, event.sha256]

    DeleteExpiredEventNip40.stub(:perform_at, worker_mock) do
      assert event.save
    end

    worker_mock.verify
  end

  test "Event that has already expired is not put to the queue" do
    expires_at = 1.day.from_now.to_i.to_s
    event = build(:event, kind: 123, tags: [["expiration", expires_at]])

    worker_mock = Minitest::Mock.new

    DeleteExpiredEventNip40.stub(:perform_at, worker_mock) do
      assert event.save
    end

    worker_mock.verify
  end

  test "Event with invalid expiration tag is not stored" do
    event = build(:event, kind: 123, tags: [["expiration", "INVALID"]])
    refute event.save
    assert_includes event.errors[:tags], "'expiration' must be unix timestamp"
  end
end
