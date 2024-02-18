class AddStartLocationToRecordings < ActiveRecord::Migration[7.1]
  def change
    add_column :recordings, :start_latitude, :decimal, precision: 10, scale: 6
    add_column :recordings, :start_longitude, :decimal, precision: 10, scale: 6

    add_index :recordings, [:start_latitude, :start_longitude]
  end
end
