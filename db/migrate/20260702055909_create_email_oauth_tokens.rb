class CreateEmailOauthTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :email_oauth_tokens do |t|
      t.string :email, null: false
      t.string :provider, null: false
      t.text :access_token
      t.text :refresh_token, null: false
      t.datetime :expires_at, null: false
      t.boolean :is_valid, default: true, null: false
      t.text :last_error

      t.timestamps
    end

    add_index :email_oauth_tokens, :email, unique: true
  end
end
