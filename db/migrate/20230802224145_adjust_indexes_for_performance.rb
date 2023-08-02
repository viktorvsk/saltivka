class AdjustIndexesForPerformance < ActiveRecord::Migration[7.0]
  def up
    add_index :authors, "pubkey varchar_pattern_ops"
    execute("CREATE INDEX index_authors_on_id_include_pubkey ON authors(id) INCLUDE(pubkey)")

    execute("CREATE INDEX index_events_for_replaceable ON events(author_id, created_at DESC, kind)")

    add_index :delete_events, :author_id

    add_index :searchable_tags, :event_id
    execute("CREATE INDEX index_searchable_tags_on_other_tags ON searchable_tags(LOWER(value) varchar_pattern_ops, event_id) WHERE name NOT IN ('e', 'p')")
    execute("CREATE INDEX index_searchable_tags_on_e_tag ON searchable_tags(LOWER(value) varchar_pattern_ops, event_id) WHERE name = 'e'")
    execute("CREATE INDEX index_searchable_tags_on_p_tag ON searchable_tags(LOWER(value) varchar_pattern_ops, event_id) WHERE name = 'p'")
  end

  def down
    remove_index :authors, "pubkey varchar_pattern_ops"
    execute("DROP INDEX index_authors_on_id_include_pubkey")

    execute("DROP INDEX index_events_for_replaceable")

    remove_index :delete_events, :author_id

    remove_index :searchable_tags, :event_id
    execute("DROP INDEX index_searchable_tags_on_other_tags")
    execute("DROP INDEX index_searchable_tags_on_e_tag")
    execute("DROP INDEX index_searchable_tags_on_p_tag")
  end
end
