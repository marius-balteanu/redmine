class AddIndexToUsersLogin < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :login
  end
end
