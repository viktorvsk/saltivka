class IndexBtreeGinOnSearchableContents < ActiveRecord::Migration[7.0]
  def change
    remove_index :searchable_contents, :tsv_content, using: :gin
    add_index :searchable_contents, [:tsv_content, :event_id], using: :gin
  end
end
