module CrazyEights
  class RoundResult
    attr_reader :current_player, :card_placed, :wild, :suit_choice
    def initialize(current_player:, card_placed:, wild: false, suit_choice: nil)
      @current_player = current_player
      @card_placed = card_placed
      @wild = wild
      @suit_choice = suit_choice
    end

    def for_other_players
      message = []
      message << "#{current_player.name} placed a #{card_placed.to_s}"

      message << "They chose the suit of #{suit_choice}" if wild

      message
    end
  end
end

