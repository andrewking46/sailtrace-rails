class CreateBoats < ActiveRecord::Migration[7.1]
  def change
    create_table :boats do |t|
      t.string :name
      t.string :registration_country, null: false
      t.string :sail_number, null: false
      t.string :hull_color, null: false
      t.references :boat_class, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
