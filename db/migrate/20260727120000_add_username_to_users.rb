class AddUsernameToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :username, :string
    backfill_usernames
    change_column_null :users, :username, false
    add_index :users, :username, unique: true
  end

  def down
    remove_column :users, :username
  end

  private

  def backfill_usernames
    User.reset_column_information
    taken = Set.new

    User.order(:id).each do |user|
      name = user.email_address.split('@').first
      name = "#{name}#{user.id}" until taken.add?(name)
      user.update_column(:username, name)
    end
  end
end
