class AddPolymorphicOrganizationToBoats < ActiveRecord::Migration[7.2]
  def change
    add_column :boats, :organization_type, :string
    add_column :boats, :organization_id, :bigint
    add_index :boats, [ :organization_type, :organization_id ]
  end
end
