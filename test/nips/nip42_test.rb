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

    test "NewEvent with kind 22242 event authenticates pubkey" do
      REDIS.sadd("connections", "CONN_ID")
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])
      redis_mock = MiniTest::Mock.new
      redis_mock.expect :call, nil, ["authentications", "CONN_ID", event.pubkey]
      REDIS.stub(:hset, redis_mock) do
        NewEvent.perform_sync("CONN_ID", event.to_json)
      end
      redis_mock.verify
    end

    test "NewEvent with kind 22242 event authenticates pubkey if already authenticated " do
      REDIS.sadd("connections", "CONN_ID")
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])
      REDIS.hset("authentications", "CONN_ID", event.pubkey)
      redis_mock = MiniTest::Mock.new
      redis_mock.expect :call, nil, ["authentications", "CONN_ID", event.pubkey]
      REDIS.stub(:hset, redis_mock) do
        NewEvent.perform_sync("CONN_ID", event.to_json)
      end
      redis_mock.verify
    end

    test "NewEvent with kind 22242 event does not authenticate pubkey if already authenticated and config restricts it" do
      REDIS.sadd("connections", "CONN_ID")
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])
      REDIS.hset("authentications", "CONN_ID", event.pubkey)
      publish_mock = MiniTest::Mock.new
      hset_mock = MiniTest::Mock.new
      publish_mock.expect :call, nil, ["events:CONN_ID:_:notice", "This connection is already authenticated. To authenticate another pubkey please open new connection"]
      REDIS.stub(:publish, publish_mock) do
        REDIS.stub(:hset, hset_mock) do
          RELAY_CONFIG.stub(:restrict_change_auth_pubkey, true) do
            NewEvent.perform_sync("CONN_ID", event.to_json)
          end
        end
      end
      publish_mock.verify
    end
  end
end
