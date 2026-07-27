module Rummy
  class RoundResult
    attr_reader :move, :current_player, :cards, :going_out

    def initialize(move:, current_player:, cards: [], going_out: false)
      @move = move.to_sym
      @current_player = current_player
      @cards = cards
      @going_out = going_out
    end

    def for_other_players
      lines = [ action_line ]
      lines << "#{current_player.name} went out and won!" if going_out
      lines
    end

    def feed_lines
      RoundFeed.new(for_other_players).lines
    end

    def self.load(hash)
      self.new(
        move: hash["move"],
        current_player: Player.load(hash["current_player"]),
        cards: hash["cards"].to_a.map { Card.load(it) },
        going_out: hash["going_out"]
      )
    end

    private

    def action_line
      case move
      when :took then "#{current_player.name} took a #{cards.first} from the discard pile"
      when :melded then "#{current_player.name} melded #{cards.join(', ')}"
      when :laid_off then "#{current_player.name} laid off #{cards.first}"
      when :discarded then "#{current_player.name} discarded a #{cards.first}"
      end
    end
  end
end
