class AddConstraintsToPayments < ActiveRecord::Migration[8.1]
  def change
    # Enforce NOT NULL constraints
    change_column_null :payments, :status, false
    change_column_null :payments, :payload, false
    change_column_null :payments, :retry_count, false

    # Add CHECK constraint for status
    execute <<-SQL
      ALTER TABLE payments
      ADD CONSTRAINT status_check
      CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled'));
    SQL
  end
end
