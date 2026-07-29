
module PlayTurnHelper
  def select_player_and_rank(page, game)
    page.select 'Fisher', from: 'Player'
    card = game.current_player.hand.first.to_s
    page.select card, from: 'Card rank'
    page.click_on "Ask for a card"
  end

  def create_go_fish_round_result(game)
    cards_exchanged = [ Card.new('A', 'Spades'), Card.new('K', 'Spades'), Card.new('Q', 'Spades') ]

    GoFish::RoundResult.new(current_user: game.current_player,
                                cards_exchanged: cards_exchanged,
                                user_in_question: game.players.last,
                                rank_in_question: 'A',
                                went_fishing: false,
                                made_a_catch: false)
  end

  def create_crazy_eights_round_result
    CrazyEights::RoundResult.new(
      current_player: CrazyEights::Player.new(0),
      card_placed: Card.new,
      wild: true,
      suit_choice: 'Hearts'
    )
  end
end
