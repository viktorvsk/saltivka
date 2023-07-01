class AddSomeIndexes < ActiveRecord::Migration[7.0]
  def change
    remove_index :searchable_tags, :event_id
    remove_index :events, :event_digest_id
    
    add_index :searchable_tags, %i[event_id name value], unique: true
    add_index :event_digests, :sha256, unique: true
    add_index :authors, :pubkey, unique: true
    add_index :events, [:created_at, :kind]
    add_index :events, :kind
    add_index :events, :event_digest_id, unique: true
    add_index :sigs, :schnorr, unique: true
  end
end
