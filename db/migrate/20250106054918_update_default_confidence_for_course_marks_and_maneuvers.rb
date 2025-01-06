class UpdateDefaultConfidenceForCourseMarksAndManeuvers < ActiveRecord::Migration[7.2]
  def change
    change_column_default :course_marks, :confidence, from: 0.5, to: 0.0
    change_column_default :maneuvers, :confidence, from: 1.0, to: 0.0
  end
end
