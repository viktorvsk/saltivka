class CreateIndexOnEventsForExpiration < ActiveRecord::Migration[7.0]
  def change
    add_index :events, :id, where: "jsonb_path_query_array(tags, '$[*][0]') ? 'expiration'"
  end
end
