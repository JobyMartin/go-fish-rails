class RummyGame < Game
  serialize :game_state, coder: Rummy::Game

  def play_turn(params)
    case params[:move]
    when "draw" then game_state.draw(params[:source])
    when "meld" then game_state.meld(Array(params[:card_ids]))
    when "layoff" then game_state.layoff(params[:meld_id].to_i, params[:card_id])
    when "discard" then game_state.discard(params[:card_id])
    when "sort" then game_state.sort_hand(params[:player].to_i)
    when "smart_sort" then game_state.smart_sort_hand(params[:player].to_i)
    end
  end

  private

  def build_game
    Rummy::Game.new(users.map { Rummy::Player.new(it.id) })
  end
end
