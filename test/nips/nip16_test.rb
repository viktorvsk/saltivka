require "test_helper"

class Nip16Test < ActiveSupport::TestCase
  test "all regular events get saved" do
    kinds = [1000, 9999, rand(1000...10000)]
    events = kinds.map do |k|
      create(:event, kind: k)
    end
    assert events.all?(&:persisted?)
  end

  test "Some protocol level kinds are replaceable events" do
    protocol_exceptions_kinds = [0, 3, 41]

    protocol_exceptions_kinds.flatten.each do |k|
      e1 = create(:event, kind: k, pubkey: FAKE_CREDENTIALS[:alice][:pk])
      e2 = create(:event, kind: k, pubkey: FAKE_CREDENTIALS[:alice][:pk])

      assert e2.reload.persisted?
      refute Event.where(id: e1.id).exists?
    end
  end

  test "Replaceable events are deleted when event with more recent created_at is saved" do
    replaceable_kinds = [rand(10000...20000), 10000, 19999]
    replaceable_kinds.flatten.each do |k|
      # debugger
      e1 = create(:event, kind: k, pubkey: FAKE_CREDENTIALS[:alice][:pk])
      e2 = create(:event, kind: k, pubkey: FAKE_CREDENTIALS[:alice][:pk])

      assert e2.reload.persisted?
      refute Event.where(id: e1.id).exists?
    end
  end

  test "Invalid replaceable event doesn't delete existing" do
    e1 = create(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk])
    e2 = build(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: 1.year.from_now)
    refute e2.save
    assert e1.reload.persisted?
    assert e2.new_record?
  end

  test "Replaceable event older than persisted one doesn't get saved" do
    e1 = create(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.now)
    e2 = build(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: 1.day.ago)
    refute e2.save
    assert e1.reload.persisted?
    assert e2.new_record?
    assert_includes e2.errors[:sha256], "has already been taken"
  end

  test "Given 2 replaceable events with the same created_at one with lexically higher id is deleted" do
    # TODO: NIP-16/NIP-33 check why order NOT matters
    e1 = create(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.at(1687970750), content: "Another") # id => f3ee61e2911b081b4ff1308222dcce30ca112e1fc8efcccf8404c6ea47363f27
    e2 = build(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.at(1687970750), content: "some") # id => 2d57c2763dfa3e500576d2b6de86d26225444a18b9c8d8414d786011ef49af56

    assert e2.save
    refute Event.where(id: e1.id).exists?
    assert e2.reload.persisted?
  end

  test "Given 2 replaceable events with the same created_at one with lexically higher id not saved" do
    e1 = create(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.at(1687970750), content: "some") # id => 2d57c2763dfa3e500576d2b6de86d26225444a18b9c8d8414d786011ef49af56
    e2 = build(:event, kind: 10001, pubkey: FAKE_CREDENTIALS[:alice][:pk], created_at: Time.at(1687970750), content: "Another") # id => f3ee61e2911b081b4ff1308222dcce30ca112e1fc8efcccf8404c6ea47363f27

    refute e2.save
    assert e1.reload.persisted?
    assert e2.new_record?
  end

  test "Ephemeral events not saved" do
    kind = [rand(20000...30000), 20000, 29999].sample
    event = build(:event, kind: kind)
    assert event.kinda?(:ephemeral)
    refute event.save
    assert_includes event.errors[:kind], "must not be ephemeral"
  end
end
