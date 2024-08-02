class AddRecordedAtToRecordedLocations < ActiveRecord::Migration[7.1]
  def change
    add_column :recorded_locations, :recorded_at, :datetime
    add_index :recorded_locations, :recorded_at
  end
end
