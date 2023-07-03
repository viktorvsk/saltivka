class CreateTrustedAuthors < ActiveRecord::Migration[7.0]
  def change
    create_table :trusted_authors do |t|
      t.references :author, index: false, foreign_key: true, null: false
      t.timestamps
    end

    add_index :trusted_authors, :author_id, unique: true
  end
end
