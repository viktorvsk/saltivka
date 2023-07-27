class AdjustOpclassIndexes < ActiveRecord::Migration[7.0]
  def up
    remove_index :authors, name: :index_authors_for_prefix_search_on_pubkey
    remove_index :events, name: :index_events_for_prefix_search_on_sha256
    remove_index :searchable_tags, name: :index_searchable_tags_for_prefix_search_on_value
    execute("CREATE INDEX index_authors_for_prefix_search_on_pubkey ON authors(LOWER(pubkey) varchar_pattern_ops)")
    execute("CREATE INDEX index_events_for_prefix_search_on_sha256 ON events(LOWER(sha256) varchar_pattern_ops)")
    execute("CREATE INDEX index_searchable_tags_for_prefix_search_on_value ON searchable_tags(LOWER(value) varchar_pattern_ops)")
  end

  def down
    remove_index :authors, name: :index_authors_for_prefix_search_on_pubkey
    remove_index :events, name: :index_events_for_prefix_search_on_sha256
    remove_index :searchable_tags, name: :index_searchable_tags_for_prefix_search_on_value
    execute("CREATE INDEX index_authors_for_prefix_search_on_pubkey ON authors(pubkey varchar_pattern_ops)")
    execute("CREATE INDEX index_events_for_prefix_search_on_sha256 ON events(sha256 varchar_pattern_ops)")
    execute("CREATE INDEX index_searchable_tags_for_prefix_search_on_value ON searchable_tags(value varchar_pattern_ops)")
  end
end
