class CreateCourseMarks < ActiveRecord::Migration[7.2]
  def change
    create_table :course_marks do |t|
      t.references :race, null: false, foreign_key: true
      t.decimal :latitude,  precision: 10, scale: 6, null: false
      t.decimal :longitude, precision: 10, scale: 6, null: false
      t.decimal :confidence, precision: 5, scale: 4, default: 0.5, null: false
      t.string :mark_type, null: false, default: "unknown"

      t.timestamps
    end

    add_index :course_marks, :mark_type
  end
end
