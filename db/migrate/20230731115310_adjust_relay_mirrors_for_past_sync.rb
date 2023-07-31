class AdjustRelayMirrorsForPastSync < ActiveRecord::Migration[7.0]
  def change
    add_column :relay_mirrors, :mirror_type, :string
    add_column :relay_mirrors, :oldest, :integer
    add_column :relay_mirrors, :newest, :integer
    remove_index :relay_mirrors, :url, unique: true
  end
end
