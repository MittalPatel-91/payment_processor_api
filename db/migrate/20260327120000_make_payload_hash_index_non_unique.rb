class MakePayloadHashIndexNonUnique < ActiveRecord::Migration[8.1]
  def change
    remove_index :payments, :payload_hash
    add_index :payments, :payload_hash
  end
end

