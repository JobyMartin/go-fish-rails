
module CreateGameHelper
  def create_game(name = 'Game', type = 'Go Fish')
    visit new_game_path
    fill_in 'Name', with: name
    select type, from: 'Type'
    click_on 'Create Game'
  end
end
