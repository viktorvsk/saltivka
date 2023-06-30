require "test_helper"

class Nip42Test < ActiveSupport::TestCase
  test "validates 22242 event according to NIP-43" do
    REDIS.sadd("connections", "secret")
    event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "secret"]], created_at: 10.seconds.ago)
    assert event.valid?
    refute event.save
    assert_includes event.errors[:kind], "must not be ephemeral"
  end

  class WithInvalidData < Nip42Test
    test "Tag 'relay' host must match" do
      event = build(:event, kind: 22242, tags: [["relay", "http://invalid"], ["challenge", "secret"]], created_at: 10.seconds.ago)
      refute event.save
      assert_includes event.errors[:tags], "'relay' must equal to ws://localhost:3000"
    end

    test "Tag 'challenge' must be present" do
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
      refute event.save
      assert_includes event.errors[:tags], "'challenge' is missing"
    end

    test "Tag 'challenge' must match one in the database" do
      REDIS.sadd("connections", "secret")
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "invalid"]], created_at: 10.seconds.ago)
      refute event.save
      assert_includes event.errors[:tags], "'challenge' is invalid"
    end

    test "created_at must not be too far in the past" do
      REDIS.sadd("connections", "secret")
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "secret"]], created_at: 1.year.ago)
      refute event.save
      assert_includes event.errors[:created_at], "is too old, must be within 600 seconds"
    end

    test "created_at must no be in future" do
      REDIS.sadd("connections", "secret")
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "secret"]], created_at: 10.seconds.from_now)
      refute event.save
      assert_includes event.errors[:created_at], "must not be in future"
    end
  end
end
