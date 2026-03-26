class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.uuid :request_uuid, null: false
      t.string :status, default: 'pending'
      t.jsonb :payload, default: {}
      t.jsonb :response, default: {}
      t.text :error_message
      t.integer :retry_count, default: 0

      t.timestamps
    end

    add_index :payments, :request_uuid, unique: true
    add_index :payments, :status
  end
end
