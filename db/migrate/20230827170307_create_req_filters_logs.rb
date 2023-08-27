class CreateReqFiltersLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :req_filters_logs do |t|
      t.jsonb :filters, default: []
      t.datetime :created_at
    end
  end
end
