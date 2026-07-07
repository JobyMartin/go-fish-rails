module GoFish
  class Game
    NUM_OF_CARDS = 5

    attr_accessor :players

    def initialize(players)
      @players = players
      @deck = Deck.new
    end

    def as_json
      {
        players: players.map(&:as_json)
      }
    end

    def self.from_json(json)
      players = json[:players].map { |player_hash| Player.load(player_hash) }
      self.new(players)
    end

    def self.load(json)
      return if json.blank?

      from_json(json)
    end

    def self.dump(obj)
      obj.as_json
    end

    def deal!
      NUM_OF_CARDS.times do
        players.each do
          it.add_cards([deck.top_card])
        end
      end
    end

    private
    attr_reader :deck
  end
end