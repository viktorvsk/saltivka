require "test_helper"

class Nip4Test < ActiveSupport::TestCase
  test "kind 4 events are not sent to subscribers without matching pubkey on NewEvent" do
    event = build(:event, kind: 4, tags: [["p", FAKE_CREDENTIALS[:alice][:pk]]])
    REDIS.hset("subscriptions", "CONN_ID:SUBID", [{kind: 4}].to_json)

    redis_mock = Minitest::Mock.new
    redis_mock.expect(:call, nil, ["events:CONN_ID:_:ok", ["OK", event.sha256, true, ""].to_json])
    REDIS.stub(:publish, redis_mock) do
      NewEvent.new.perform("CONN_ID", event.to_json)
    end
    redis_mock.verify
  end

  test "kind 4 events are not sent if no p-tag present on NewEvent" do
    event = build(:event, kind: 4)
    REDIS.hset("subscriptions", "CONN_ID:SUBID", [{kind: 4}].to_json)

    redis_mock = Minitest::Mock.new
    redis_mock.expect(:call, nil, ["events:CONN_ID:_:ok", ["OK", event.sha256, true, ""].to_json])
    REDIS.stub(:publish, redis_mock) do
      NewEvent.new.perform("CONN_ID", event.to_json)
    end
    redis_mock.verify
  end

  test "kind 4 events are only sent to subscribers with matching pubkey" do
    event = build(:event, kind: 4, tags: [["p", FAKE_CREDENTIALS[:alice][:pk]]])
    REDIS.hset("subscriptions", "CONN_ID:SUBID", [{kind: 4}].to_json)
    REDIS.hset("authentications", "CONN_ID", FAKE_CREDENTIALS[:alice][:pk])

    redis_mock = Minitest::Mock.new
    redis_mock.expect(:call, nil, ["events:CONN_ID:SUBID:found_event", event.to_json])
    redis_mock.expect(:call, nil, ["events:CONN_ID:_:ok", ["OK", event.sha256, true, ""].to_json])

    REDIS.stub(:publish, redis_mock) do
      NewEvent.new.perform("CONN_ID", event.to_json)
    end
    redis_mock.verify
  end

  test "kind 4 events are not sent to valid subscribers without matching filters" do
    event = build(:event, kind: 4, tags: [["p", FAKE_CREDENTIALS[:alice][:pk]]])
    REDIS.hset("subscriptions", "CONN_ID:SUBID", [{kinds: [1]}].to_json)
    REDIS.hset("authentications", "CONN_ID", FAKE_CREDENTIALS[:alice][:pk])

    redis_mock = Minitest::Mock.new
    redis_mock.expect(:call, nil, ["events:CONN_ID:_:ok", ["OK", event.sha256, true, ""].to_json])

    REDIS.stub(:publish, redis_mock) do
      NewEvent.new.perform("CONN_ID", event.to_json)
    end
    redis_mock.verify
  end

  class EventByNostrFilters < Nip4Test
    test "kinds [4] => 4 by p-tag and author" do
      e1 = create(:event, kind: 4, pubkey: FAKE_CREDENTIALS[:alice][:pk])
      e2 = create(:event, kind: 4, tags: [["p", FAKE_CREDENTIALS[:alice][:pk]]])
      create(:event, kind: 4, pubkey: FAKE_CREDENTIALS[:bob][:pk], tags: [["p", FAKE_CREDENTIALS[:bob][:pk]]])
      assert_equal [e1.id, e2.id].sort, Event.by_nostr_filters({kinds: [4]}, FAKE_CREDENTIALS[:alice][:pk]).to_a.map(&:id).sort
    end

    test "kinds [4] => finds by delegation" do
      tags = [
        ["p", FAKE_CREDENTIALS[:alice][:pk]],
        ["delegation", FAKE_CREDENTIALS[:carl][:pk], "kind=4", "b05bd5636223b546d2a5f0f5875c2558647558ed94df5378ae34ac053c5cd7d40d524b1c763b7cda096eb8da0cd4ff744cd0946e895c39ea54727cb26257df1e"]
      ]
      e1 = create(:event, kind: 4, pubkey: FAKE_CREDENTIALS[:bob][:pk], tags: tags, created_at: Time.at(1688051860))
      create(:event, kind: 1, pubkey: FAKE_CREDENTIALS[:alice][:pk])
      create(:event, kind: 4, pubkey: FAKE_CREDENTIALS[:alice][:pk])

      assert_equal [e1.id], Event.by_nostr_filters({kinds: [4]}, FAKE_CREDENTIALS[:carl][:pk]).to_a.map(&:id).sort
    end

    test "kinds [1, 4] => 1 + 4 by p-tag, author and delegation" do
      e1 = create(:event, kind: 4, pubkey: FAKE_CREDENTIALS[:alice][:pk])
      e2 = create(:event, kind: 4, tags: [["p", FAKE_CREDENTIALS[:alice][:pk]]])
      e3 = create(:event, kind: 1)
      create(:event, kind: 4, pubkey: FAKE_CREDENTIALS[:bob][:pk], tags: [["p", FAKE_CREDENTIALS[:bob][:pk]]])
      assert_equal [e1.id, e2.id, e3.id].sort, Event.by_nostr_filters({kinds: [1, 4]}, FAKE_CREDENTIALS[:alice][:pk]).to_a.map(&:id).sort
    end

    class WithoutPubkeyTest < EventByNostrFilters
      test "No kinds filtered => Ignores kind 4 events" do
        create(:event, kind: 4)
        assert_empty Event.by_nostr_filters({})
      end

      test "kind [1,4] => 1" do
        e1 = create(:event, kind: 1)
        create(:event, kind: 4)
        assert_equal [e1.id], Event.by_nostr_filters({kinds: [1, 4]}).to_a.map(&:id)
      end
    end
  end
end
