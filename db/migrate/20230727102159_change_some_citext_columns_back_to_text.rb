class ChangeSomeCitextColumnsBackToText < ActiveRecord::Migration[7.0]
  def up
    change_column :authors, :pubkey, :text
    change_column :events, :sha256, :text
    change_column :searchable_tags, :value, :text
  end

  def down
    change_column :authors, :pubkey, :citext
    change_column :events, :sha256, :citext
    change_column :searchable_tags, :value, :citext
  end
end
