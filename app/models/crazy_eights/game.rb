module CrazyEights
  class Game
    BIG_GAME_PLAYER_COUNT = 3
    BIG_GAME_DEAL_COUNT = 5
    SMALL_GAME_DEAL_COUNT = 7

    attr_accessor :players, :deck

    def initialize(players, deck = Deck.new)
      @players = players
      @deck = deck
    end
    def self.load(json)

    end

    def self.dump(obj)
      obj.as_json
    end

    def deal!
      number_of_cards.times do
        players.each do
          it.add_cards([deck.top_card])
        end
      end
    end

    def find_player(user_id)
      players.find { it.id == user_id }
    end

    private

    def number_of_cards
      players.count < BIG_GAME_PLAYER_COUNT ? SMALL_GAME_DEAL_COUNT : BIG_GAME_DEAL_COUNT
    end
  end
end