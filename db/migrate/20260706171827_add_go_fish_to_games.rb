class AddGoFishToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :go_fish, :jsonb
  end
end
