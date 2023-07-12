class CreateAuthorSubscriptions < ActiveRecord::Migration[7.0]
  def change
    create_table :author_subscriptions do |t|
      t.references :author, index: false, foreign_key: true, null: false
      t.datetime :expires_at
      t.timestamps
    end

    add_index :author_subscriptions, :author_id, unique: true
  end
end
