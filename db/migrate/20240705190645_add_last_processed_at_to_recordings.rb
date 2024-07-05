class AddLastProcessedAtToRecordings < ActiveRecord::Migration[7.1]
  def change
    add_column :recordings, :last_processed_at, :datetime
    add_index :recordings, :last_processed_at
  end
end
