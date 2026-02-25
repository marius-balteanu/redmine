class AddIndexToUsersLowerLogin < ActiveRecord::Migration[8.1]
  def up
    add_index :users, "(lower(login))", name: "index_users_on_lower_login"
  end

  def down
    remove_index :users, name: "index_users_on_lower_login"
  end
end
