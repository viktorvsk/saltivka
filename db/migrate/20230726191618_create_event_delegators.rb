class CreateEventDelegators < ActiveRecord::Migration[7.0]
  def change
    create_table :event_delegators do |t|
      t.references :event, index: false, foreign_key: true, null: false
      t.references :author, index: false, foreign_key: true, null: false
    end

    add_index :event_delegators, :event_id, unique: true
    add_index :event_delegators, %i[event_id author_id]
  end
end
