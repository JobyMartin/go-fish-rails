class RemoveSizeFromGames < ActiveRecord::Migration[8.1]
  def change
    remove_column :games, :size, :integer
  end
end
