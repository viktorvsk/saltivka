class AddBtreeGinExtension < ActiveRecord::Migration[7.0]
  def change
    enable_extension "btree_gin"
  end
end
