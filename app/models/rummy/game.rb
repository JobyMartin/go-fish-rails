module Rummy
  class Game
    TWO_PLAYER_DEAL_COUNT = 10
    SMALL_GAME_DEAL_COUNT = 7
    BIG_GAME_DEAL_COUNT = 6
    SMALL_GAME_PLAYER_COUNT = 4

    attr_accessor :players, :deck, :current_player_index, :round_results, :melds, :discard_pile, :drawn_this_turn,
                  :taken_from_discard

    def initialize(players, deck = Deck.new, current_player_index = 0, round_results = [], melds = [],
                   discard_pile = [], drawn_this_turn = false, taken_from_discard = nil)
      @players = players
      @deck = deck
      @current_player_index = current_player_index
      @round_results = round_results
      @melds = melds
      @discard_pile = discard_pile
      @drawn_this_turn = drawn_this_turn
      @taken_from_discard = taken_from_discard
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
        drawn_this_turn: drawn_this_turn,
        taken_from_discard: taken_from_discard&.as_json
      }
    end

    def self.from_json(json)
      players = json["players"].map { |player_hash| Player.load(player_hash) }
      deck = Deck.load(json["deck"])
      round_results = json["round_results"].map { |round_hash| RoundResult.load(round_hash) }
      melds = json["melds"].map { |meld_hash| Meld.load(meld_hash) }
      discard_pile = json["discard_pile"].map { |card_hash| Card.load(card_hash) }
      taken_from_discard = json["taken_from_discard"] && Card.load(json["taken_from_discard"])
      self.new(players, deck, json["current_player_index"], round_results, melds, discard_pile,
                json["drawn_this_turn"], taken_from_discard)
    end

    def deal!
      number_of_cards.times { players.each { |player| player.add_cards([ deck.top_card ]) } }
      self.discard_pile = [ deck.top_card ]
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

    def sort_hand(player_id)
      find_player(player_id)&.sort_hand!
    end

    def smart_sort_hand(player_id)
      find_player(player_id)&.smart_sort_hand!
    end

    def active_card = discard_pile.last

    def draw(source)
      card = source == "discard" ? take_from_discard : take_from_deck
      current_player.add_cards([ card ])
      record_move(:took, [ card ]) if source == "discard"
      self.taken_from_discard = source == "discard" ? card : nil
      self.drawn_this_turn = true
    end

    def meld(card_tokens)
      cards = cards_from_hand(card_tokens)
      raise InvalidMove, "That's not a valid set or run." unless Meld.valid?(cards)

      cards.each { |card| remove_from_hand(card) }
      melds << Meld.new(cards)
      current_player.mark_melded!
      record_move(:melded, cards)
    end

    def layoff(meld_id, card_token)
      meld = melds[meld_id]
      card = cards_from_hand([ card_token ]).first
      raise InvalidMove, "You have to lay down a meld of your own before laying off." unless current_player.melded?
      raise InvalidMove, "That card can't be added to this meld." unless meld && card && Meld.valid?(meld.cards + [ card ])

      remove_from_hand(card)
      meld.cards << card
      record_move(:laid_off, [ card ])
    end

    def discard(card_token)
      card = cards_from_hand([ card_token ]).first
      raise InvalidMove, "Pick a card from your hand to discard." unless card
      raise InvalidMove, "You can't discard the card you just took from the discard pile." if taken_from_discard && card == taken_from_discard

      remove_from_hand(card)
      discard_pile << card
      record_move(:discarded, [ card ])
      end_turn
    end

    private

    def take_from_discard
      raise InvalidMove, "The discard pile is empty." if discard_pile.empty?

      discard_pile.pop
    end

    def take_from_deck
      refill_deck_from_discard_pile if deck.empty?
      deck.top_card
    end

    def refill_deck_from_discard_pile
      raise InvalidMove, "There are no cards left to draw." if discard_pile.size <= 1

      deck.cards.concat(discard_pile.shift(discard_pile.size - 1))
    end

    def record_move(move, cards)
      round_results << RoundResult.new(
        move: move, current_player: current_player, cards: cards, going_out: current_player.hand.empty?
      )
    end

    def end_turn
      self.drawn_this_turn = false
      switch_turns unless current_player.hand.empty?
    end

    def number_of_cards
      return TWO_PLAYER_DEAL_COUNT if players.count == 2

      players.count <= SMALL_GAME_PLAYER_COUNT ? SMALL_GAME_DEAL_COUNT : BIG_GAME_DEAL_COUNT
    end

    def cards_from_hand(card_tokens)
      card_tokens.reject(&:blank?).map { |token| current_player.hand.find { it == Card.objectify(token) } }.compact
    end

    def remove_from_hand(card)
      current_player.hand.delete_at(current_player.hand.index(card))
    end

    def switch_turns
      if current_player_index == players.length - 1
        self.current_player_index = 0
      else
        self.current_player_index += 1
      end
    end
  end
end
