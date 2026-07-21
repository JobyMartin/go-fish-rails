class CrazyEightsGame < Game
  serialize :game_state, coder: CrazyEights::Game

  def play_turn(params)
    active_card = game_state.william.active_card
    placed_card = params[:rank]
    if placed_card.present?
      game_state.play_turn(active_card, Card.objectify(placed_card))
    else
      draw_until_playable(active_card)
    end
  end

  private

  def draw_until_playable(active_card)
    drawn_cards = [game_state.deck.top_card]
    until drawn_cards.any? { it.suit == active_card.suit || it.rank == active_card.rank }
      drawn_cards << game_state.deck.top_card
    end
    placed_card = drawn_cards.pop
    game_state.current_player.add_cards(drawn_cards)
    game_state.play_turn(active_card, placed_card)
  end

  def build_game
    CrazyEights::Game.new(users.map { CrazyEights::Player.new(it.id) })
  end
end