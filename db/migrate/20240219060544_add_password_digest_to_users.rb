class AddPasswordDigestToUsers < ActiveRecord::Migration[7.1]
  def change
    change_table :users do |t|
      t.string :password_digest, null: false
    end

    remove_column :users, :date_of_birth, :date
  end
end
