class AddIndexesForNip33 < ActiveRecord::Migration[7.0]
  def up
    remove_index :events, name: :index_events_for_replaceable
    execute("CREATE INDEX index_searchable_tags_on_d_tag ON searchable_tags(lower(value), event_id) WHERE name = 'd'")
    add_index :events, %i[author_id created_at kind], where: "kind IN (0,3,41) OR kind BETWEEN 10000 AND 19999 OR kind BETWEEN 30000 AND 39999", name: :index_events_for_replaceable
  end

  def down
    remove_index(:searchable_tags, name: :index_searchable_tags_on_d_tag)
    remove_index(:events, name: :index_events_for_replaceable)
    execute("CREATE INDEX index_events_for_replaceable ON events(author_id, created_at DESC, kind)")
  end
end
