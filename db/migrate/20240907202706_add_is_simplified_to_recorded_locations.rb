class AddIsSimplifiedToRecordedLocations < ActiveRecord::Migration[7.2]
  def change
    add_column :recorded_locations, :is_simplified, :boolean, default: false
    add_index :recorded_locations, :is_simplified
  end
end
