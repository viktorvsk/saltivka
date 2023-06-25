class ExtractEventDigestFromEvents < ActiveRecord::Migration[7.0]
  def up
    drop_table :events

    create_table "events" do |t|
      t.integer "kind", null: false
      t.jsonb "tags", default: []
      t.text "content"
      t.datetime "created_at"
      t.references :author, index: true, foreign_key: true, null: false
      t.references :event_digest, index: true, foreign_key: true, null: false
    end
  end

  def down
    drop_table :events

    create_table "events", id: {type: :string, limit: 64} do |t|
      t.integer "kind", null: false
      t.jsonb "tags", default: []
      t.text "content"
      t.string "sig", limit: 128, null: false
      t.datetime "created_at"
      t.bigint "author_id", null: false
      t.index ["author_id"], name: "index_events_on_author_id"
    end
  end
end
