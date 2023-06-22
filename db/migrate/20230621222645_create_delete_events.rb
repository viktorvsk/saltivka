class CreateDeleteEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :delete_events do |t|
      t.string :event_id, null: false, limit: 64
      t.string :pubkey, null: false, limit: 64
      t.datetime :created_at
    end

    add_index :delete_events, [:event_id, :pubkey], unique: true
  end
end
