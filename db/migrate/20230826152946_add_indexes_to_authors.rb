class AddIndexesToAuthors < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute("CREATE INDEX CONCURRENTLY index_authors_on_lower_pubkey_and_id ON authors(lower(pubkey), id)")
    execute("CREATE INDEX CONCURRENTLY index_authors_on_id_and_lower_pubkey ON authors(id, lower(pubkey))")
  end

  def down
    remove_index :authors, name: :index_authors_on_lower_pubkey_and_id
    remove_index :authors, name: :index_authors_on_id_and_lower_pubkey
  end
end
