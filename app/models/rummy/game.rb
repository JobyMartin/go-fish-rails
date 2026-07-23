module Rummy
  class Game
    DEMO_HAND = [
      Card.new("3", "Hearts"), Card.new("4", "Hearts"), Card.new("5", "Hearts"),
      Card.new("6", "Hearts"), Card.new("9", "Spades"), Card.new("9", "Diamonds"),
      Card.new("2", "Clubs"), Card.new("K", "Spades")
    ].freeze

    DEMO_MELDS = [
      %w[7_Spades 8_Spades 9_Spades],
      %w[Q_Hearts Q_Diamonds Q_Clubs],
      %w[3_Hearts 4_Hearts 5_Hearts 6_Hearts],
      %w[9_Spades 9_Diamonds 9_Hearts 9_Clubs],
      %w[10_Spades J_Spades Q_Spades K_Spades],
      %w[10_Hearts J_Hearts Q_Hearts],
      %w[K_Spades K_Hearts K_Diamonds K_Clubs]
    ].freeze

    OPPONENT_HAND_SIZE = 5

    attr_accessor :players, :deck, :current_player_index, :round_results, :melds, :discard_pile, :drawn_this_turn

    def initialize(players, deck = Deck.new, current_player_index = 0, round_results = [], melds = [],
                   discard_pile = [], drawn_this_turn = false)
      @players = players
      @deck = deck
      @current_player_index = current_player_index
      @round_results = round_results
      @melds = melds
      @discard_pile = discard_pile
      @drawn_this_turn = drawn_this_turn
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
        melds: melds.map(&:as_json),
        discard_pile: discard_pile.as_json,
        drawn_this_turn: drawn_this_turn
      }
    end

    def self.from_json(json)
      players = json["players"].map { |player_hash| Player.load(player_hash) }
      deck = Deck.load(json["deck"])
      round_results = json["round_results"].map { |round_hash| RoundResult.load(round_hash) }
      melds = json["melds"].map { |meld_hash| Meld.load(meld_hash) }
      discard_pile = json["discard_pile"].map { |card_hash| Card.load(card_hash) }
      self.new(players, deck, json["current_player_index"], round_results, melds, discard_pile,
                json["drawn_this_turn"])
    end

    def deal!
      players.first.add_cards(DEMO_HAND)
      players.drop(1).each { |player| player.add_cards(Array.new(OPPONENT_HAND_SIZE) { deck.top_card }) }
      self.melds = DEMO_MELDS.map { |cards| Meld.new(cards.map { |card| card_from_token(card) }) }
      self.discard_pile = [ Card.new("K", "Clubs") ]
    end

    def find_player(user_id)
      players.find { it.id == user_id }
    end

    def current_player = players[current_player_index]

    def game_over?
      players.any? { it.hand.empty? }
    end

    def winner
      players.find { it.hand.empty? }
    end

    def active_card = discard_pile.last

    private

    def card_from_token(token)
      rank, suit = token.split("_")
      Card.new(rank, suit)
    end
  end
end
