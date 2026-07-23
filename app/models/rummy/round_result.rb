module Rummy
  class RoundResult
    attr_reader :current_player, :card_discarded, :card_taken, :going_out

    def initialize(current_player:, card_discarded: nil, card_taken: nil, going_out: false)
      @current_player = current_player
      @card_discarded = card_discarded
      @card_taken = card_taken
      @going_out = going_out
    end

    def for_other_players
      return [ "#{current_player.name} took a #{card_taken} from the discard pile" ] if card_taken

      message = [ "#{current_player.name} discarded a #{card_discarded}" ]
      message << "#{current_player.name} went out and won!" if going_out
      message
    end

    def feed_lines
      RoundFeed.new(for_other_players).lines
    end

    def self.load(hash)
      self.new(
        current_player: Player.load(hash["current_player"]),
        card_discarded: hash["card_discarded"] && Card.load(hash["card_discarded"]),
        card_taken: hash["card_taken"] && Card.load(hash["card_taken"]),
        going_out: hash["going_out"]
      )
    end
  end
end
