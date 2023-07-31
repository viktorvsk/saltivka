class CreateRelayMirrors < ActiveRecord::Migration[7.0]
  def change
    create_table :relay_mirrors do |t|
      t.string :url, null: false
      t.boolean :active, default: false
      t.timestamps
    end

    add_index :relay_mirrors, :url, unique: true
  end
end
