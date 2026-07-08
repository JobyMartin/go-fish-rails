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
      round_results = json['round_results'].map { |round_hash| RoundResult.load(round_hash) }
      self.new(players, deck, json['current_player_index'], round_results)
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

    def find_player(user_id)
      players.find { it.id == user_id }
    end

    def play_turn(inquired_player_id, inquired_rank)
      inquired_player = find_player(inquired_player_id)
      cards_exchanged = inquired_player.get_cards_by_rank(inquired_rank)
      
      handle_cards_and_end_turn(cards_exchanged, inquired_player_id, inquired_rank)
    end

    def winner
      player_books = players.map { it.books }

      if player_books.all? { it.length == player_books.first.length }
        handle_tie
      else
        handle_winner
      end
    end

    private

    def handle_tie
      winner = current_player

      players.each do
        winner = it if it.highest_book_value > winner.highest_book_value
      end

      winner
    end

    def handle_winner
      players.first.books.size > players.last.books.size ? winner = players.first : winner = players.last

      winner
    end

    def handle_cards_and_end_turn(cards_exchanged, inquired_player_id, inquired_rank)
      if cards_exchanged.any?
        current_player.add_cards(cards_exchanged)
        end_turn(cards_exchanged, find_player(inquired_player_id), false, inquired_rank)
      else
        end_turn(cards_exchanged, find_player(inquired_player_id), (go_fish.rank != inquired_rank), inquired_rank)
      end
    end

    def go_fish
      fished_card = deck.top_card
      current_player.add_cards([fished_card])

      current_player.make_book_if_possible(fished_card.rank) unless current_player.hand.empty?

      fished_card
    end

    def end_turn(cards_exchanged, inquired_user, turn_over, inquired_rank)
      cards_exchanged.each { current_player.make_book_if_possible(it.rank) }

      round_results << GoFish::RoundResult.new(current_user: current_player,
                                      cards_exchanged: cards_exchanged,
                                      user_in_question: inquired_user,
                                      rank_in_question: inquired_rank,
                                      went_fishing: went_fishing?(cards_exchanged, turn_over),
                                      made_a_catch: made_a_catch?(cards_exchanged, turn_over))
      switch_players if turn_over
    end

    def went_fishing?(cards_exchanged, turn_over)
      turn_over && cards_exchanged.empty?
    end

    def made_a_catch?(cards_exchanged, turn_over)
      !turn_over && cards_exchanged.empty?
    end

    def switch_players
      if current_player_index == players.length - 1
        self.current_player_index = 0
      else
        self.current_player_index += 1
      end
    end
  end
end