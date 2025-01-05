class AddWindDataToRecordings < ActiveRecord::Migration[7.2]
  def change
    add_column :recordings, :wind_direction_degrees, :integer
    add_column :recordings, :wind_direction_cardinal, :string
    add_column :recordings, :wind_speed, :decimal, precision: 5, scale: 2
  end
end
