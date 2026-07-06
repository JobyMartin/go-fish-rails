module GoFish
  class Player
    STARTING_BOOK_VALUE = 0

    attr_reader :name
    attr_accessor :hand, :books

    def initialize(name)
      @name = name
      @hand = []
      @books = []
    end

    def add_cards(cards)
      cards.each { |card| hand << card }
      make_book_if_possible(cards.first.rank) unless cards.empty?
    end

    def get_cards_by_rank(rank)
      find_by_rank = ->(card) { card.rank == rank }

      cards_of_rank = hand.select(&find_by_rank)
      hand.delete_if(&find_by_rank)
      
      cards_of_rank
    end

    def hand_size = hand.size

    def book_size = books.size

    def formatted_hand
      formatted_hand = ''

      hand.each do |card|
        formatted_hand += "- #{card.rank} of #{card.suit}\n"
      end

      formatted_hand
    end

    def make_book_if_possible(rank)
      cards = hand.select { it.rank == rank }

      if cards.count == 4
        self.hand -= cards
        books << GoFish::Book.new(cards)
      end
    end

    def formatted_books
      formatted_books = "Books:\n"

      books.each do
        formatted_books += "- #{it.cards.first.rank}\n"
      end

      formatted_books
    end

    def highest_book_value
      highest_book_value = STARTING_BOOK_VALUE

      books.each do
        highest_book_value = it.value if it.value > highest_book_value
      end

      highest_book_value
    end

    def as_json
      {
        'name' => name,
        'books' => books.map(&:rank),
        'book_count' => book_size
      }
    end
  end
end