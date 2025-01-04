class CreateManeuvers < ActiveRecord::Migration[7.2]
  def change
    create_table :maneuvers do |t|
      t.references :recording, null: false, foreign_key: true
      t.decimal :cumulative_heading_change, precision: 6, scale: 2, null: false, default: 0.0
      t.decimal :latitude,  precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.datetime :occurred_at, null: false
      t.string :maneuver_type, null: false, default: "unknown"
      t.decimal :confidence, precision: 5, scale: 4, default: 1.0, null: false

      t.timestamps
    end

    add_index :maneuvers, :maneuver_type
    add_index :maneuvers, :occurred_at
  end
end
