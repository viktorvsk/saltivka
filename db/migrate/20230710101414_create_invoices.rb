class CreateInvoices < ActiveRecord::Migration[7.0]
  def change
    create_table :invoices do |t|
      t.references :author, index: true, foreign_key: true, null: false
      t.integer :amount_sats, null: false
      t.integer :period_days, null: false
      t.string :provider, null: false
      t.string :status, null: false, default: "pending"
      t.string :external_id
      t.string :order_id, null: false

      t.jsonb :request, default: {}
      t.jsonb :response, default: {}
      t.jsonb :webhooks, default: []
      t.datetime :paid_at
      t.timestamps
    end

    add_index :invoices, :order_id, unique: true
    add_index :invoices, [:external_id, :provider], unique: true
  end
end
