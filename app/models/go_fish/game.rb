module GoFish
  class Game
    NUM_OF_CARDS = 5

    attr_reader :deck
    attr_accessor :players, :current_player_index, :round_results

    def initialize(players, deck = Deck.new, current_player_index = 0, round_results = [])
      @players = players
      @deck = deck
      @current_player_index = current_player_index
      @round_results = round_results
    end

    def as_json
      {
        players: players.map(&:as_json),
        current_player_index: current_player_index,
        deck: deck.as_json,
        round_results: round_results.as_json
      }
    end

    def self.from_json(json)
      players = json['players'].map { |player_hash| Player.load(player_hash) }
      deck = Deck.load(json['deck'])
      self.new(players, deck, json['current_player_index'], json['round_results'])
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

    def current_player = players[current_player_index]
  end
end