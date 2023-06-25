class CreateSigs < ActiveRecord::Migration[7.0]
  def change
    create_table :sigs, id: false do |t|
      t.string :schnorr, null: false, limit: 128
      t.bigint :event_digest_id, primary_key: true
    end

    add_foreign_key :sigs, :event_digests
  end
end
