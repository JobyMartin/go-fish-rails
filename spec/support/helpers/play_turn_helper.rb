
module PlayTurnHelper
  def select_player_and_rank(page, game)
    # page.select 'Fisher', from: 'Player', visible: false
    page.select 'Fisher', from: 'player', visible: :all, disabled: :all
    card = game.current_player.hand.first.to_s
    page.select card, from: 'rank', visible: false
    page.click_on "Ask for a card"
  end
end