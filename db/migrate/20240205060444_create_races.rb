class CreateRaces < ActiveRecord::Migration[7.1]
  def change
    create_table :races do |t|
      t.string :name
      t.datetime :started_at, null: false
      t.decimal :start_latitude, precision: 10, scale: 6, null: false
      t.decimal :start_longitude, precision: 10, scale: 6, null: false
      t.references :boat_class, null: true, foreign_key: true

      t.timestamps
    end

    add_reference :recordings, :race, foreign_key: true, null: true
  end
end
