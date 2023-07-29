class AdjustClusterIndexes < ActiveRecord::Migration[7.0]
  def up
    execute("CLUSTER authors USING index_authors_on_lower_pubkey_varchar_pattern_ops")
    execute("CLUSTER delete_events USING index_delete_events_on_sha256_and_author_id")
    execute("CLUSTER event_delegators USING index_event_delegators_on_event_id_and_author_id")
    execute("CLUSTER events USING index_events_on_created_at_and_kind")
    execute("CLUSTER searchable_tags USING index_searchable_tags_on_event_id_and_name_and_value")
  end

  def down
    execute("ALTER TABLE authors SET WITHOUT CLUSTER")
    execute("ALTER TABLE delete_events SET WITHOUT CLUSTER")
    execute("ALTER TABLE event_delegators SET WITHOUT CLUSTER")
    execute("ALTER TABLE events SET WITHOUT CLUSTER")
    execute("ALTER TABLE searchable_tags SET WITHOUT CLUSTER")
  end
end
