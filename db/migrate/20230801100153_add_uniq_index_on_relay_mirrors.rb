class AddUniqIndexOnRelayMirrors < ActiveRecord::Migration[7.0]
  def change
    add_index :relay_mirrors, %i[url mirror_type], unique: true
  end
end
