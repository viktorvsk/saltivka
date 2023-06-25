class CreateAuthors < ActiveRecord::Migration[7.0]
  def change
    create_table :authors do |t|
      t.string :pubkey, null: false, limit: 64
    end
  end
end
