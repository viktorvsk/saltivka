# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2023_06_24_143008) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "authors", force: :cascade do |t|
    t.string "pubkey", limit: 64, null: false
  end

  create_table "delete_events", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.bigint "event_digest_id", null: false
    t.index ["event_digest_id", "author_id"], name: "index_delete_events_on_event_digest_id_and_author_id", unique: true
  end

  create_table "event_digests", force: :cascade do |t|
    t.string "sha256", limit: 64, null: false
  end

  create_table "events", force: :cascade do |t|
    t.integer "kind", null: false
    t.jsonb "tags", default: []
    t.text "content"
    t.datetime "created_at"
    t.bigint "author_id", null: false
    t.bigint "event_digest_id", null: false
    t.index ["author_id"], name: "index_events_on_author_id"
    t.index ["event_digest_id"], name: "index_events_on_event_digest_id"
  end

  create_table "searchable_tags", id: false, force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name", limit: 64, null: false
    t.string "value", limit: 128, null: false
    t.index ["event_id"], name: "index_searchable_tags_on_event_id"
  end

  create_table "sigs", primary_key: "event_digest_id", force: :cascade do |t|
    t.string "schnorr", limit: 128, null: false
  end

  add_foreign_key "delete_events", "authors"
  add_foreign_key "delete_events", "event_digests"
  add_foreign_key "events", "authors"
  add_foreign_key "events", "event_digests"
  add_foreign_key "searchable_tags", "events"
  add_foreign_key "sigs", "event_digests"
end
