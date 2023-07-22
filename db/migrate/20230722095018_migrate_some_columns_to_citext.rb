class MigrateSomeColumnsToCitext < ActiveRecord::Migration[7.0]
  def up
    change_column :authors, :pubkey, :citext
    change_column :delete_events, :sha256, :citext
    change_column :events, :sha256, :citext
    change_column :events, :sig, :citext
    change_column :invoices, :provider, :citext
    change_column :invoices, :status, :citext
    change_column :invoices, :order_id, :citext
  end

  def down
    change_column :authors, :pubkey, :string
    change_column :delete_events, :sha256, :string
    change_column :events, :sha256, :string
    change_column :events, :sig, :string
    change_column :invoices, :provider, :string
    change_column :invoices, :status, :string
    change_column :invoices, :order_id, :string
  end
end
