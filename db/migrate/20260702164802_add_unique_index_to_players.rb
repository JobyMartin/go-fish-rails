class AddUniqueIndexToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_index :players, [ :game_id, :user_id ], unique: true
  end
end
