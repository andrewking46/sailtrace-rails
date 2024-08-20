class CreateAccessTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :access_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.string :refresh_token, null: false
      t.datetime :refresh_token_expires_at, null: false

      t.timestamps
    end

    add_index :access_tokens, :token, unique: true
    add_index :access_tokens, :refresh_token, unique: true
  end
end
