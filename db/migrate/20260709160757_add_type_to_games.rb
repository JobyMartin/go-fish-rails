class AddTypeToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :type, :string
  end
end
