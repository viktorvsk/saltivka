class AddConfirmedAtToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :confirmed_at, :datetime
    add_index :users, :confirmed_at
  end
end
