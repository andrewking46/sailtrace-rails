class AddAccuracyToRecordedLocations < ActiveRecord::Migration[7.1]
  def change
    add_column :recorded_locations, :accuracy, :decimal, precision: 5, scale: 2
  end
end
