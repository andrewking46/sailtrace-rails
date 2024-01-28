class CreateRecordedLocations < ActiveRecord::Migration[7.1]
  def change
    create_table :recorded_locations do |t|
      t.decimal :latitude, precision: 10, scale: 6, null: false
      t.decimal :longitude, precision: 10, scale: 6, null: false
      t.decimal :velocity
      t.integer :heading
      t.references :recording, null: false, foreign_key: true

      t.timestamps
    end
  end
end
