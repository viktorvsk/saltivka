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

ActiveRecord::Schema[7.0].define(version: 2023_07_27_102633) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

  create_table "author_subscriptions", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_author_subscriptions_on_author_id", unique: true
  end

  create_table "authors", force: :cascade do |t|
    t.text "pubkey", null: false
    t.index "lower(pubkey) varchar_pattern_ops", name: "index_authors_for_prefix_search_on_pubkey"
    t.index "lower(pubkey)", name: "index_authors_on_lower_pubkey", unique: true
  end

  create_table "delete_events", id: false, force: :cascade do |t|
    t.citext "sha256", null: false
    t.bigint "author_id", null: false
    t.index ["sha256", "author_id"], name: "index_delete_events_on_sha256_and_author_id", unique: true
  end

  create_table "event_delegators", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "author_id", null: false
    t.index ["event_id", "author_id"], name: "index_event_delegators_on_event_id_and_author_id"
    t.index ["event_id"], name: "index_event_delegators_on_event_id", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.integer "kind", null: false
    t.jsonb "tags", default: []
    t.binary "content"
    t.bigint "author_id", null: false
    t.text "sha256", null: false
    t.citext "sig", null: false
    t.datetime "created_at"
    t.index "lower(sha256) varchar_pattern_ops", name: "index_events_for_prefix_search_on_sha256"
    t.index "lower(sha256)", name: "index_events_on_lower_sha256", unique: true
    t.index ["author_id"], name: "index_events_on_author_id"
    t.index ["created_at", "kind"], name: "index_events_on_created_at_and_kind"
    t.index ["kind"], name: "index_events_on_kind"
    t.index ["sig"], name: "index_events_on_sig", unique: true
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.integer "amount_sats", null: false
    t.integer "period_days", null: false
    t.citext "provider", null: false
    t.citext "status", default: "pending", null: false
    t.string "external_id"
    t.citext "order_id", null: false
    t.jsonb "request", default: {}
    t.jsonb "response", default: {}
    t.jsonb "webhooks", default: []
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_invoices_on_author_id"
    t.index ["external_id", "provider"], name: "index_invoices_on_external_id_and_provider", unique: true
    t.index ["order_id"], name: "index_invoices_on_order_id", unique: true
  end

  create_table "searchable_tags", id: false, force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.text "value", null: false
    t.index "event_id, name, lower(value)", name: "index_searchable_tags_on_event_id_and_name_and_value", unique: true
    t.index "lower(value) varchar_pattern_ops", name: "index_searchable_tags_for_prefix_search_on_value"
  end

  create_table "trusted_authors", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_trusted_authors_on_author_id", unique: true
  end

  create_table "user_pubkeys", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_user_pubkeys_on_author_id", unique: true
    t.index ["user_id"], name: "index_user_pubkeys_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "crypted_password"
    t.string "salt"
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "confirmed_at"
    t.string "reset_password_token"
    t.datetime "reset_password_token_expires_at"
    t.datetime "reset_password_email_sent_at"
    t.integer "access_count_to_reset_password_page", default: 0
    t.index ["confirmed_at"], name: "index_users_on_confirmed_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token"
  end

  add_foreign_key "author_subscriptions", "authors"
  add_foreign_key "delete_events", "authors"
  add_foreign_key "event_delegators", "authors"
  add_foreign_key "event_delegators", "events"
  add_foreign_key "events", "authors"
  add_foreign_key "invoices", "authors"
  add_foreign_key "searchable_tags", "events"
  add_foreign_key "trusted_authors", "authors"
  add_foreign_key "user_pubkeys", "authors"
  add_foreign_key "user_pubkeys", "users"
end
