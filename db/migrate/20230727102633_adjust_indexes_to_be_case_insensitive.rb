class AdjustIndexesToBeCaseInsensitive < ActiveRecord::Migration[7.0]
  def up
    remove_index :authors, :pubkey
    remove_index :events, :sha256
    remove_index :searchable_tags, %i[event_id name value]
    add_index :authors, "lower(pubkey)", unique: true
    add_index :events, "lower(sha256)", unique: true
    execute("CREATE UNIQUE INDEX index_searchable_tags_on_event_id_and_name_and_value ON searchable_tags(event_id, name, lower(value))")
  end

  def down
    remove_index :authors, name: :index_authors_on_lower_pubkey
    remove_index :events, name: :index_events_on_lower_sha256
    remove_index :searchable_tags, name: :index_searchable_tags_on_event_id_and_name_and_value
    add_index :authors, :pubkey, unique: true
    add_index :events, :sha256, unique: true
    add_index :searchable_tags, [:event_id, :name, :value], unique: true
  end
end
