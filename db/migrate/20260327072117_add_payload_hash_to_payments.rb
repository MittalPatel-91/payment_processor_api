class AddPayloadHashToPayments < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :payload_hash, :string, null: false
    add_index :payments, :payload_hash, unique: true
  end
end
