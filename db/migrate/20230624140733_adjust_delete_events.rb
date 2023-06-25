class AdjustDeleteEvents < ActiveRecord::Migration[7.0]
  def up
    drop_table :delete_events

    create_table "delete_events", force: :cascade do |t|
      t.references :author, index: false, foreign_key: true, null: false
      t.references :event_digest, index: false, foreign_key: true, null: false
    end

    add_index :delete_events, %i[event_digest_id author_id], unique: true
  end

  def down
    drop_table :delete_events

    create_table "delete_events", force: :cascade do |t|
      t.string "event_id", limit: 64, null: false
      t.string "pubkey", limit: 64, null: false
      t.datetime "created_at"
      t.index ["event_id", "pubkey"], name: "index_delete_events_on_event_id_and_pubkey", unique: true
    end
  end
end
