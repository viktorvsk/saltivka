class CreateSearchableContents < ActiveRecord::Migration[7.0]
  def change
    create_table :searchable_contents, id: false do |t|
      t.references :event, index: false, foreign_key: true, null: false
      t.string :language, null: false
      t.tsvector :tsv_content, null: false
    end

    add_index :searchable_contents, :event_id, unique: true
    add_index :searchable_contents, :tsv_content, using: :gin
  end
end
