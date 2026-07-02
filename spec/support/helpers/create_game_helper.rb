
module CreateGameHelper
  def create_game(name = 'Game', type = 'Go Fish')
    visit new_game_path
    fill_in 'Name', with: name
    select type, from: 'Game type'
    click_on 'Create Game'
  end
end
