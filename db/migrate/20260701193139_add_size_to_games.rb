class AddSizeToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :size, :integer, null: false
  end
end
