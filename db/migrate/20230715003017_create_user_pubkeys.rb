class CreateUserPubkeys < ActiveRecord::Migration[7.0]
  def change
    create_table :user_pubkeys do |t|
      t.references :author, index: false, foreign_key: true, null: false
      t.references :user, index: true, foreign_key: true, null: false
      t.timestamps
    end

    add_index :user_pubkeys, %i[author_id], unique: true
  end
end
