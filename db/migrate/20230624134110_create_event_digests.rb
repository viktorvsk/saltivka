class CreateEventDigests < ActiveRecord::Migration[7.0]
  def change
    create_table :event_digests do |t|
      t.string :sha256, null: false, limit: 64
    end
  end
end
