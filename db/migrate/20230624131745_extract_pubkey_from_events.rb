class ExtractPubkeyFromEvents < ActiveRecord::Migration[7.0]
  def up
    remove_column :events, :pubkey
    add_column :events, :author_id, :bigint, null: false
    add_index :events, :author_id
    add_foreign_key :events, :authors
  end

  def down
    add_column :events, :string, :pubkey, null: false, limit: 64
  end
end
