class AddNip05NameToUserPubkeys < ActiveRecord::Migration[7.0]
  def change
    add_column :user_pubkeys, :nip05_name, :citext
    add_index :user_pubkeys, :nip05_name, unique: true, where: "nip05_name IS NOT NULL AND nip05_name != ''"
  end
end
