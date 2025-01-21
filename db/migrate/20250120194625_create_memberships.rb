class CreateMemberships < ActiveRecord::Migration[7.2]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.string :organization_type, null: false
      t.bigint :organization_id, null: false

      t.timestamps
    end

    add_index :memberships, [ :organization_type, :organization_id ]
    add_index :memberships, [ :user_id, :organization_type, :organization_id ], unique: true
  end
end
