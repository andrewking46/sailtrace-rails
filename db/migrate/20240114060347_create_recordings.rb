class CreateRecordings < ActiveRecord::Migration[7.1]
  def change
    create_table :recordings do |t|
      t.string :name
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.string :time_zone, null: false
      t.boolean :is_race, null: false, default: false
      t.references :boat, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
