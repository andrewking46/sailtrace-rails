class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email_address, null: false
      t.string :phone_number
      t.string :country
      t.string :time_zone
      t.date :date_of_birth, null: false
      t.boolean :is_admin, null: false, default: false

      t.timestamps
    end

    add_index :users, :username, unique: true
    add_index :users, :email_address, unique: true
    add_index :users, :is_admin
  end
end
