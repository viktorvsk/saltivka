class CreateEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :events do |t|
      t.integer :kind, null: false, limit: 3
      t.jsonb :tags, default: []
      t.binary :content, limit: 8.megabytes
      t.references :author, index: true, foreign_key: true, null: false
      t.string :sha256, null: false, limit: 64
      t.string :sig, null: false, limit: 128
      t.datetime :created_at
    end

    add_index :events, [:created_at, :kind]
    add_index :events, :kind
    add_index :events, :sha256, unique: true
    add_index :events, :sig, unique: true
  end
end
