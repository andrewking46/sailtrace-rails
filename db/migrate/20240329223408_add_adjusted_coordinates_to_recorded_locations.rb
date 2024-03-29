class AddAdjustedCoordinatesToRecordedLocations < ActiveRecord::Migration[7.1]
  def change
    add_column :recorded_locations, :adjusted_latitude, :decimal, precision: 10, scale: 6
    add_column :recorded_locations, :adjusted_longitude, :decimal, precision: 10, scale: 6
  end
end
