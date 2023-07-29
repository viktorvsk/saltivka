class AdjustIndexesOnEvents < ActiveRecord::Migration[7.0]
  def up
    remove_index :events, :sig
    remove_index :events, name: :index_events_on_lower_sha256
    remove_index :events, name: :index_events_for_prefix_search_on_sha256
    add_index :events, "lower(sha256) varchar_pattern_ops", unique: true
  end

  def down
    add_index :events, :sig, unique: true
    add_index :events, "lower(sha256)", name: :index_events_on_lower_sha256, unique: true
    add_index :events, "lower(sha256) varchar_pattern_ops", name: :index_events_for_prefix_search_on_sha256
    remove_index :events, name: :index_events_on_lower_sha256_varchar_pattern_ops
  end
end
