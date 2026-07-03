class AddWinnerToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :winner, :boolean
  end
end
