class AdjustIndexesOnAuthors < ActiveRecord::Migration[7.0]
  def up
    remove_index :authors, name: :index_authors_on_lower_pubkey
    remove_index :authors, name: :index_authors_for_prefix_search_on_pubkey
    add_index :authors, "lower(pubkey) varchar_pattern_ops", unique: true
  end

  def down
    add_index :authors, "lower(pubkey) varchar_pattern_ops", name: "index_authors_for_prefix_search_on_pubkey"
    add_index :authors, "lower(pubkey)", name: "index_authors_on_lower_pubkey", unique: true
    remove_index :authors, name: :index_authors_on_lower_pubkey_varchar_pattern_ops
  end
end
