class SorceryCore < ActiveRecord::Migration[7.0]
  def change
    create_table :users do |t|
      t.string :email, null: false, index: {unique: true}
      t.string :crypted_password
      t.string :salt
      t.boolean :admin, default: false, null: false

      t.timestamps null: false
    end
  end
end
