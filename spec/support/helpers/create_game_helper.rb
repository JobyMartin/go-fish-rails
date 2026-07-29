
module CreateGameHelper
  def create_game(name = 'Game', type = 'Go Fish')
    visit new_game_path
    fill_in 'Name', with: name
    select type, from: 'Type'
    click_on 'Create Game'
  end

  # The start button stays disabled below Game::MINIMUM_PLAYERS, so a spec that only
  # signs in one user has to seat an opponent before it can start the game.
  def start_game_with_opponent(game = nil)
    expect(page).to have_button('Start game', disabled: :all)
    game ||= Game.last
    create_list(:player, Game::MINIMUM_PLAYERS - game.players.count, game:)
    visit game_path(game)
    click_on 'Start game'
  end
end
