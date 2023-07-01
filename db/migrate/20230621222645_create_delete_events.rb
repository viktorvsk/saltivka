class CreateDeleteEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :delete_events, id: false do |t|
      t.string :sha256, null: false, limit: 64
      t.references :author, index: false, foreign_key: true, null: false
    end

    add_index :delete_events, %i[sha256 author_id], unique: true
  end
end
