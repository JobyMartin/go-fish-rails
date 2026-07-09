class RemoveGameTypeFromGames < ActiveRecord::Migration[8.1]
  def change
    remove_column :games, :game_type, :integer
  end
end
