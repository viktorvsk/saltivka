require "test_helper"

class EventTest < ActiveSupport::TestCase
  setup do
    sk = "945e01e37662430162121b804d3645a86d97df9d256917d86735d0eb219393eb"
    pk = "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"
    event_digest = "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"
    sig = Schnorr.sign([event_digest].pack("H*"), [sk].pack("H*")).encode.unpack1("H*")
    event_params = {
      created_at: Time.at(1687183979),
      kind: 0,
      tags: [],
      content: "",
      pubkey: pk,
      digest_and_sig: [event_digest, sig]
    }

    @event = Event.create!(event_params)
  end

  test "nostr format serialization" do
    assert true, @event.persisted?
    assert "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f", Digest::SHA256.hexdigest(JSON.dump(@event.to_nostr_serialized))
  end

  test "Single event matching filter_set" do
    event_with_tags = create(:event, kind: 1, tags: [["e", "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"], ["p", "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]])

    parsed_json = JSON.parse(File.read(Rails.root.join(*%w[test fixtures files nostr_event_delegated.json])))
    delegated_event_params = parsed_json.merge("digest_and_sig" => [parsed_json.delete("id"), parsed_json.delete("sig")], "created_at" => Time.at(parsed_json["created_at"]))
    delegated_event = Event.new(delegated_event_params)

    assert delegated_event.matches_nostr_filter_set?({"authors" => ["8e0d3d"]})
    assert delegated_event.matches_nostr_filter_set?({"authors" => ["09cd08d"]})

    assert @event.matches_nostr_filter_set?({"ids" => ["bf84a73"]})
    assert @event.matches_nostr_filter_set?({"authors" => ["a19f19f"]})
    refute @event.matches_nostr_filter_set?({"authors" => ["_a19f19f"]})

    assert event_with_tags.matches_nostr_filter_set?({"#e" => ["bf84a"]})
    assert event_with_tags.matches_nostr_filter_set?({"#p" => ["a19f19"]})
    refute event_with_tags.matches_nostr_filter_set?({"#e" => ["a19f19"]})

    assert build(:event, kind: 4).matches_nostr_filter_set?({"kinds" => [4]})
    refute build(:event, kind: 3).matches_nostr_filter_set?({"kinds" => [4]})
    refute build(:event, kind: 4, created_at: 1.hour.ago).matches_nostr_filter_set?({"kinds" => [4], "until" => 2.days.ago.to_i})
    assert build(:event, kind: 4, created_at: 1.day.ago).matches_nostr_filter_set?({"kinds" => [4], "until" => 2.hour.ago.to_i})
    assert build(:event, created_at: 1.hour.ago).matches_nostr_filter_set?({"since" => 2.days.ago.to_i})
    refute build(:event, created_at: 1.day.ago).matches_nostr_filter_set?({"since" => 2.hour.ago.to_i})
  end

  # Here we test a use case where we have implemented new filter
  # added it to AVAILABLE FILTERS but for some reason missed to handle it
  test "edge filter" do
    RELAY_CONFIG.stub(:available_filters, %w[kinds ids authors #e #p since until edge_filter]) do
      refute build(:event).matches_nostr_filter_set?({"edge_filter" => 2.hour.ago.to_i})
    end
  end

  test "NIP-26: valid delegation event" do
    parsed_json = JSON.parse(File.read(Rails.root.join(*%w[test fixtures files nostr_event_delegated.json])))
    event_params = parsed_json.merge("digest_and_sig" => [parsed_json.delete("id"), parsed_json.delete("sig")], "created_at" => Time.at(parsed_json["created_at"]))
    event = Event.new(event_params)

    assert event.valid?
  end

  test "NIP-26: invalid delegation" do
    too_old_event = build(:event, :delegated_event, kind: 1, created_at: 1.year.ago)
    too_new_event = build(:event, :delegated_event, kind: 1, created_at: 1.day.from_now)
    invalid_kind_event = build(:event, :delegated_event, kind: 1001, created_at: 1.day.ago)
    invalid_delegation_pubkey_event = build(:event, tags: [["delegation", "INVALID", "", ""]])

    refute too_old_event.valid?
    refute too_new_event.valid?
    refute invalid_kind_event.valid?
    refute invalid_delegation_pubkey_event.valid?

    assert_includes too_old_event.errors[:tags], %('delegation' created_at < event created_at minimum)
    assert_includes too_new_event.errors[:tags], %('delegation' created_at > event created_at maximum)
    assert_includes invalid_kind_event.errors[:tags], %('delegation' kind doesn't allow kind 1001)
    assert_includes invalid_delegation_pubkey_event.errors[:tags], %('delegation' pubkey must be a valid 64 characters hex)
  end

  test "Find Events mathcing filter_set in database" do
    event_with_tags = create(:event, kind: 1, tags: [["e", "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"], ["p", "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]])

    parsed_json = JSON.parse(File.read(Rails.root.join(*%w[test fixtures files nostr_event_delegated.json])))
    event_params = parsed_json.merge("digest_and_sig" => [parsed_json.delete("id"), parsed_json.delete("sig")], "created_at" => Time.at(parsed_json["created_at"]))
    Event.create!(event_params)

    assert_equal 1, Event.by_nostr_filters({"authors" => ["09cd08d"]}).to_a.size
    assert_equal 1, Event.by_nostr_filters({"authors" => ["8e0d3"]}).to_a.size

    assert_equal 3, Event.by_nostr_filters({}).count
    assert_equal 1, Event.by_nostr_filters({limit: 1}).count
    assert_equal 1, Event.by_nostr_filters({kinds: 0}).count
    assert_equal 2, Event.by_nostr_filters({"authors" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95", event_with_tags.pubkey.first(5)]}).count
    assert_equal ((event_with_tags.pubkey == "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95") ? 2 : 1), Event.by_nostr_filters({"authors" => ["a19f19f63dc65c8053c9"]}).count
    assert_equal 2, Event.by_nostr_filters({"ids" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f", event_with_tags.event_digest.sha256.first(5)]}).count
    assert_equal 1, Event.by_nostr_filters({"ids" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]}).count
    assert_equal 3, Event.by_nostr_filters({"ids" => []}).count
    assert_equal 0, Event.by_nostr_filters({"ids" => ["INVALID"]}).count
    assert_equal 0, Event.by_nostr_filters({"#e" => ["s"]}).count
    assert_equal 1, Event.by_nostr_filters({"#e" => ["b"]}).count
    assert_equal 1, Event.by_nostr_filters({"#p" => ["a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"]}).count
    assert_equal 0, Event.by_nostr_filters({"#p" => ["bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"]}).count
  end

  test "NIP-16: all regular events get saved" do
    kinds = [1000, 9999, rand(1000...10000)]
    events = kinds.map do |k|
      create(:event, kind: k)
    end
    assert events.all?(&:persisted?)
  end

  test "NIP-16: some protocol level kinds are replaceable events" do
    protocol_exceptions_kinds = [0, 3, 41]

    protocol_exceptions_kinds.flatten.each do |k|
      # debugger
      e1 = create(:event, kind: k, pubkey: FAKE_CREDENTIALS[:alice][:pk])
      e2 = create(:event, kind: k, pubkey: FAKE_CREDENTIALS[:alice][:pk])

      assert e2.reload.persisted?
      refute Event.where(id: e1.id).exists?
    end
  end

  test "NIP-16: replaceable events are deleted when event with more recent created_at is saved" do
    replaceable_kinds = [rand(10000...20000), 10000, 19999]
    replaceable_kinds.flatten.each do |k|
      # debugger
      e1 = create(:event, kind: k, pubkey: FAKE_CREDENTIALS[:alice][:pk])
      e2 = create(:event, kind: k, pubkey: FAKE_CREDENTIALS[:alice][:pk])

      assert e2.reload.persisted?
      refute Event.where(id: e1.id).exists?
    end
  end

  test "NIP-16 invalid replaceable event doesn't delete existing" do
    e1 = create(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk])
    e2 = build(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: 1.year.from_now)
    refute e2.save
    assert e1.reload.persisted?
    assert e2.new_record?
  end

  test "NIP-16: replaceable event older than persisted one doesn't get saved" do
    e1 = create(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.now)
    e2 = build(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: 1.day.ago)
    refute e2.save
    assert e1.reload.persisted?
    assert e2.new_record?
    assert_includes e2.errors[:"event_digest.sha256"], "has already been taken"
  end

  test "NIP-16: given 2 replaceable events with the same created_at one with lexically higher id is deleted" do
    # TODO: NIP-16/NIP-33 check why order NOT matters
    e2 = build(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.at(1687970750), content: "some") # id => 2d57c2763dfa3e500576d2b6de86d26225444a18b9c8d8414d786011ef49af56
    e1 = create(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.at(1687970750), content: "Another") # id => f3ee61e2911b081b4ff1308222dcce30ca112e1fc8efcccf8404c6ea47363f27

    assert e2.save
    refute Event.where(id: e1.id).exists?
    assert e2.reload.persisted?
  end

  test "NIP-16: given 2 replaceable events with the same created_at one with lexically higher id not saved" do
    e1 = create(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.at(1687970750), content: "some") # id => 2d57c2763dfa3e500576d2b6de86d26225444a18b9c8d8414d786011ef49af56
    e2 = build(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.at(1687970750), content: "Another") # id => f3ee61e2911b081b4ff1308222dcce30ca112e1fc8efcccf8404c6ea47363f27

    refute e2.save
    assert e1.reload.persisted?
    assert e2.new_record?
  end

  test "NIP-16: ephemeral events not saved" do
    kind = [rand(20000...30000), 20000, 29999].sample
    event = build(:event, kind: kind)
    assert event.kinda?(:ephemeral)
    refute event.save
    assert_includes event.errors[:kind], "must not be ephemeral"
  end

  test "PoW difficulty NIP-13" do
    with_pow = JSON.parse(File.read(Rails.root.join("test", "fixtures", "files", "nostr_event_pow.json")))
    event_with_pow = with_pow.merge({
      "created_at" => Time.at(with_pow["created_at"]),
      "digest_and_sig" => [with_pow.delete("id"), with_pow.delete("sig")]
    })

    assert Event.new(event_with_pow).valid?
    assert @event.valid?
    RELAY_CONFIG.stub(:min_pow, 1) do
      assert Event.new(event_with_pow).valid?
      refute @event.valid?
    end
  end

  class Nip9 < EventTest
    test "Event of kind 5 deletes proper saved Event" do
      event = create(:event, kind: 1)
      create(:event, kind: 5, pubkey: event.pubkey, tags: [["e", event.sha256]])

      refute Event.where(id: event.id).exists?
    end

    test "Deleted event (pubkey+id) are not saved" do
      event = build(:event, kind: 1)
      create(:event, kind: 5, pubkey: event.pubkey, tags: [["e", event.sha256]])

      assert DeleteEvent.by_pubkey_and_sha256(event.pubkey, event.sha256).exists?
      refute event.valid?
      assert_includes event.errors[:id], "is already listed as deleted"
    end

    test "kind 5 event without valid pubkey in e tag doesn't save" do
      event = build(:event, kind: 5, tags: [["e", "INVALID"]])

      refute event.save
      assert_includes event.errors[:tags], "'e' tag must have a valid hex pubkey as a last (and second) element for kind 5 event (DeleteEvent)"
    end

    test "kind 5 event without e tag doesn't save" do
      event = build(:event, kind: 5, tags: [["x", @event.sha256]])

      refute event.save
      assert_includes event.errors[:tags], "must have 'e' entry for kind 5 event (DeleteEvent)"
    end

    test "does not delete kind 5 events since there is no support for undo delete" do
      event = create(:event, kind: 5, pubkey: @event.pubkey, tags: [["e", @event.sha256]])
      other_event = build(:event, kind: 5, pubkey: event.pubkey, tags: [["e", event.sha256]])
      assert other_event.save
      assert event.reload.persisted?
    end
  end

  class Nip12 < EventTest
    test "creates SearchableTag association only for the first value" do
      event = create(:event, kind: 123, pubkey: @event.pubkey, tags: [["r", "payload", "only first is value is indexed"]])
      assert_equal 1, event.searchable_tags.count
    end

    test "matches event by #r filter" do
      event = create(:event, kind: 123, pubkey: @event.pubkey, tags: [["r", "payload"]])
      assert event.matches_nostr_filter_set?({"#r" => ["payload"]})
      assert event.matches_nostr_filter_set?({"#r" => ["one of options is", "payload", "other"]})
      assert event.matches_nostr_filter_set?({"#r" => ["paylo"]})

      assert_equal 1, Event.by_nostr_filters({"#r" => ["payload"]}).count
      assert_equal 1, Event.by_nostr_filters({"#r" => ["one of options is", "payload", "other"]}).count
      assert_equal 1, Event.by_nostr_filters({"#r" => ["paylo"]}).count
    end
  end

  class Nip40 < EventTest
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
end
