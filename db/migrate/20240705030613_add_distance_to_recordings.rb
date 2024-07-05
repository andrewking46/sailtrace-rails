class AddDistanceToRecordings < ActiveRecord::Migration[7.1]
  def change
    add_column :recordings, :distance, :decimal
  end
end
