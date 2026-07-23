module Rummy
  class RoundResult
    attr_reader :current_player, :card_discarded

    def initialize(current_player:, card_discarded:)
      @current_player = current_player
      @card_discarded = card_discarded
    end

    def for_other_players
      [ "#{current_player.name} discarded a #{card_discarded}" ]
    end

    def feed_lines
      RoundFeed.new(for_other_players).lines
    end

    def self.load(hash)
      self.new(
        current_player: Player.load(hash["current_player"]),
        card_discarded: Card.load(hash["card_discarded"])
      )
    end
  end
end
