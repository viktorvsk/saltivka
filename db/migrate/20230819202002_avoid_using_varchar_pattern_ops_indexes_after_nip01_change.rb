class AvoidUsingVarcharPatternOpsIndexesAfterNip01Change < ActiveRecord::Migration[7.0]
  def up
    remove_index :authors, name: :index_authors_on_lower_pubkey_varchar_pattern_ops
    remove_index :authors, name: :index_authors_on_pubkey_varchar_pattern_ops # We won't create this index
    remove_index :events, name: :index_events_on_lower_sha256_varchar_pattern_ops
    remove_index :searchable_tags, name: :index_searchable_tags_for_prefix_search_on_value  # We won't create this index
    remove_index :searchable_tags, name: :index_searchable_tags_on_e_tag
    remove_index :searchable_tags, name: :index_searchable_tags_on_other_tags
    remove_index :searchable_tags, name: :index_searchable_tags_on_p_tag

    add_index :authors, "lower(pubkey)", unique: true
    add_index :events, "lower(sha256)", unique: true
    execute("CREATE INDEX index_searchable_tags_on_e_tag ON searchable_tags(lower(value), event_id) WHERE name = 'e'")
    execute("CREATE INDEX index_searchable_tags_on_p_tag ON searchable_tags(lower(value), event_id) WHERE name = 'p'")
    execute("CREATE INDEX index_searchable_tags_on_other_tags ON searchable_tags(lower(value), event_id) WHERE name NOT IN ('e', 'p')")
  end

  def down
    remove_index :authors, "lower(pubkey)", unique: true
    remove_index :events, "lower(sha256)", unique: true
    remove_index :searchable_tags, name: :index_searchable_tags_on_e_tag
    remove_index :searchable_tags, name: :index_searchable_tags_on_p_tag
    remove_index :searchable_tags, name: :index_searchable_tags_on_other_tags

    execute("CREATE UNIQUE INDEX index_authors_on_lower_pubkey_varchar_pattern_ops ON authors(lower(pubkey) varchar_pattern_ops)")
    execute("CREATE INDEX index_authors_on_pubkey_varchar_pattern_ops ON authors(pubkey varchar_pattern_ops)")
    execute("CREATE UNIQUE INDEX index_events_on_lower_sha256_varchar_pattern_ops ON events(lower(sha256) varchar_pattern_ops)")
    execute("CREATE INDEX index_searchable_tags_for_prefix_search_on_value ON searchable_tags(lower(value) varchar_pattern_ops)")
    execute("CREATE INDEX index_searchable_tags_on_e_tag ON searchable_tags(lower(value) varchar_pattern_ops, event_id) WHERE name = 'e'")
    execute("CREATE INDEX index_searchable_tags_on_p_tag ON searchable_tags(lower(value) varchar_pattern_ops, event_id) WHERE name = 'p'")
    execute("CREATE INDEX index_searchable_tags_on_other_tags ON searchable_tags(lower(value) varchar_pattern_ops, event_id) WHERE name NOT IN ('e', 'p')")
  end
end
