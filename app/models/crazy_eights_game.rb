class CrazyEightsGame < Game
  serialize :game_state, coder: CrazyEights::Game

  def play_turn(active_card, placed_card = nil)
    if placed_card
      game_state.play_turn(active_card, CrazyEights::Card.objectify(placed_card))
    else
      drawn_cards = [game_state.deck.top_card]
      until drawn_cards.any? { it.suit == active_card.suit || it.rank == active_card.rank }
        drawn_cards << game_state.deck.top_card
      end
      placed_card = drawn_cards.pop
      game_state.current_player.add_cards(drawn_cards)
      game_state.play_turn(active_card, CrazyEights::Card.objectify(placed_card))
    end
  end
end