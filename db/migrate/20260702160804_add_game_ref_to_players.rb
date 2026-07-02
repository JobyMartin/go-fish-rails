class AddGameRefToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_reference :players, :game, null: false, foreign_key: true
  end
end
