class CreateEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :events, id: false do |t|
      t.string :id, null: false, limit: 64, primary_key: true
      t.string :pubkey, null: false, limit: 64
      t.integer :kind, null: false, limit: 3
      t.jsonb :tags, default: "[]"
      t.text :content, limit: 8.megabytes
      t.string :sig, null: false, limit: 128
      t.datetime :created_at
    end
  end
end
