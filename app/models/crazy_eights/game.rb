module CrazyEights
  class Game
    BIG_GAME_PLAYER_COUNT = 3
    BIG_GAME_DEAL_COUNT = 5
    SMALL_GAME_DEAL_COUNT = 7

    attr_accessor :players, :deck, :current_player_index, :round_results, :william

    def initialize(players, deck = Deck.new, current_player_index = 0, round_results = [], william = William.new([deck.top_card]))
      @players = players
      @deck = deck
      @current_player_index = current_player_index
      @round_results = round_results
      @william = william
    end
    def self.load(json)
      return if json.blank?

      from_json(json)
    end

    def self.dump(obj)
      obj.as_json
    end

    def as_json
      {
        players: players.map(&:as_json),
        current_player_index: current_player_index,
        deck: deck.as_json,
        round_results: round_results.as_json,
        william: william.as_json
      }
    end

    def self.from_json(json)
      players = json['players'].map { |player_hash| Player.load(player_hash) }
      deck = Deck.load(json['deck'])
      round_results = json['round_results'].map { |round_hash| RoundResult.load(round_hash) }
      william = William.load(json['william'])
      self.new(players, deck, json['current_player_index'], round_results, william)
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

    def current_player = players[current_player_index]

    private

    def number_of_cards
      players.count < BIG_GAME_PLAYER_COUNT ? SMALL_GAME_DEAL_COUNT : BIG_GAME_DEAL_COUNT
    end
  end
end