class CreateBoatClasses < ActiveRecord::Migration[7.1]
  def change
    create_table :boat_classes do |t|
      t.string :name, null: false
      t.boolean :is_one_design, null: false, default: false

      t.timestamps
    end

    add_index :boat_classes, :name, unique: true
  end
end
