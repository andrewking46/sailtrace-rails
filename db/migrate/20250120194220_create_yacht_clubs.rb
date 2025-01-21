class CreateYachtClubs < ActiveRecord::Migration[7.2]
  def change
    create_table :yacht_clubs do |t|
      t.string :name, null: false
      t.string :abbreviation
      t.string :street_address
      t.string :city
      t.string :subdivision_code
      t.string :subdivision
      t.string :postal_code
      t.string :country_code
      t.string :country
      t.string :time_zone
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :phone
      t.string :email
      t.boolean :is_active, default: false, null: false

      t.timestamps
    end
    add_index :yacht_clubs, :name
  end
end
