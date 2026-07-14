class RenameGoFishtoGameStateInGames < ActiveRecord::Migration[8.1]
  def change
    rename_column :games, :go_fish, :game_state
  end
end
