class CreateSearchableTags < ActiveRecord::Migration[7.0]
  def change
    create_table :searchable_tags, id: false do |t|
      t.references :event, index: true, foreign_key: true, null: false
      t.string :name, null: false, limit: 1
      t.string :value, null: false, limit: 128
    end
  end
end
