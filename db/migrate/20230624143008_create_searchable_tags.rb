class CreateSearchableTags < ActiveRecord::Migration[7.0]
  def change
    create_table :searchable_tags, id: false do |t|
      t.references :event, index: false, foreign_key: true, null: false
      t.string :name, null: false
      t.string :value, null: false
    end

    add_index :searchable_tags, %i[event_id name value], unique: true
  end
end
