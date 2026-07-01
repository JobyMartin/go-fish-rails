class AddNameToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :name, :string, null: false
  end
end
