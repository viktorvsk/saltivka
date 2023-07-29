class AdjustIndexesOnSaearchableTags < ActiveRecord::Migration[7.0]
  def up
    remove_index :searchable_tags, name: :index_searchable_tags_for_prefix_search_on_value
  end

  def down
    add_index :searchable_tags, "lower(value) varchar_pattern_ops", name: "index_searchable_tags_for_prefix_search_on_value"
  end
end
