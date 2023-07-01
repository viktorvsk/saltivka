require "test_helper"

class Nip33Test < ActiveSupport::TestCase
  test "only works for parameterized_replaceable events kinds" do
    e1 = create(:event, kind: 1, tags: [["d", "value"]], content: "A")
    e2 = create(:event, kind: 1, tags: [["d", "value"]], content: "B")
    e3 = create(:event, kind: 1, tags: [["d", "value"]], content: "C")

    assert e1.reload.persisted?
    assert e2.reload.persisted?
    assert e3.reload.persisted?
  end

  test "removes older events with the same kind:pubkey:d_tag" do
    event = create(:event, kind: 30000, tags: [["d", "payload"]], content: "A")
    create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d", "payload"]], content: "B")

    refute Event.where(id: event.id).exists?
  end

  test "treats empty and non-canonical d-tag values as empty" do
    event = create(:event, kind: 30000, tags: [["d", ""]], content: "A")

    event2 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d", ""]], content: "B")
    refute Event.where(id: event.id).exists?

    event3 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d"]], content: "C")
    refute Event.where(id: event2.id).exists?

    event4 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [], content: "D")
    refute Event.where(id: event3.id).exists?

    event5 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d", "", "payload"]], content: "E")
    refute Event.where(id: event4.id).exists?

    event6 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d", ""], ["d", "payload"]], content: "F")
    refute Event.where(id: event5.id).exists?

    event7 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d"], ["d", "payload"]], content: "G")
    refute Event.where(id: event6.id).exists?

    event8 = create(:event, kind: 30000, pubkey: event.pubkey, tags: [["d", "", "payload"]], content: "H")
    refute Event.where(id: event7.id).exists?

    create(:event, kind: 30000, pubkey: event.pubkey, tags: [["e"]], content: "K")
    refute Event.where(id: event8.id).exists?
  end

  # {:kind=>30000, :content=>"A", :pubkey=>"a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95", :created_at=>1687996745, :id=>"59eb98fd7ca938bbedde0123c210015eefb3fc53470148177a16528b67292e73", :sig=>"10290602351775ae2a4c17db81a774e8acce7d32a1c539f8a47b2dd334360e0cadefb1d74a4447888fff169fffa04c28f8570b362d9ba2e2c79e41418c7894ca", :tags=>[["d", ""]]}
  # {:kind=>30000, :content=>"B", :pubkey=>"a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95", :created_at=>1687996745, :id=>"e7fa021e4516df70554c9b3c5d303732498b8488ef80931cfdfe48a6104fd399", :sig=>"bdc96cf93e0dbfb77665abbf6a9c358f7120a2f276dd0e6330112bf8b3578ac4b3e4ff8b7ef5451411e65483faf32524382d1c71f3c71de61e97e839d85476f7", :tags=>[["d", ""]]}

  test "removes events with the same kind:pubkey:d_tag:created_at leaving lower ids" do
    # TODO: NIP-16/NIP-33 check why order matters
    higher_id_event = create(:event, kind: 30000, pubkey: FAKE_CREDENTIALS[:alice][:pk], tags: [["d", ""]], created_at: Time.at(1687996745), content: "B") # id => e7fa021e4516df70554c9b3c5d303732498b8488ef80931cfdfe48a6104fd399
    lower_id_event = build(:event, kind: 30000, pubkey: FAKE_CREDENTIALS[:alice][:pk], tags: [["d", ""]], created_at: Time.at(1687996745), content: "A") # id => 59eb98fd7ca938bbedde0123c210015eefb3fc53470148177a16528b67292e73

    assert lower_id_event.save
    refute Event.where(id: higher_id_event.id).exists?
  end

  test "doesn't save event with higher id and the same kind:pubkey:d_tag" do
    lower_id_event = create(:event, kind: 30000, tags: [["d", ""]], content: "A", created_at: Time.at(1687996745), pubkey: FAKE_CREDENTIALS[:alice][:pk]) # id => 59eb98fd7ca938bbedde0123c210015eefb3fc53470148177a16528b67292e73
    higher_id_event = build(:event, kind: 30000, tags: [["d", ""]], content: "B", created_at: Time.at(1687996745), pubkey: FAKE_CREDENTIALS[:alice][:pk]) # id => e7fa021e4516df70554c9b3c5d303732498b8488ef80931cfdfe48a6104fd399

    refute higher_id_event.save
    assert_includes higher_id_event.errors[:sha256], "has already been taken"
    assert lower_id_event.reload.persisted?
  end

  test "doesn't save older event with the same kind:pubkey:d_tag" do
    event = create(:event, kind: 30000, created_at: Time.now)
    older_event = build(:event, kind: 30000, pubkey: event.pubkey, created_at: 2.days.ago)

    refute older_event.save
    assert_includes older_event.errors[:sha256], "has already been taken"
    assert event.reload.persisted?
  end

  test "implicit d-tag is added to Event#searchable_tags of parameterized_replaceable kind" do
    event = create(:event, kind: 30000, tags: [], content: "A")
    assert_empty event.searchable_tags.where(name: "d").first.value
    assert_equal [], event.reload.tags
  end

  test "implicit d-tag is not added to Event#searchable_tags of regular kind" do
    event = create(:event, kind: 2222, tags: [], content: "A")
    assert_nil event.searchable_tags.where(name: "d").first
    assert_equal [], event.reload.tags
  end

  test "only the first value is indexed" do
    event = create(:event, kind: 30000, tags: [["d", "", "payload"]], content: "E")
    assert_equal [""], event.searchable_tags.pluck(:value)
  end
end
