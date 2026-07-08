module GoFish
  class Player
    STARTING_BOOK_VALUE = 0

    attr_reader :name, :id
    attr_accessor :hand, :books

    def initialize(id = 0, name = 'Fisher', hand = [], books = [])
      @id = id
      @name = name
      @hand = hand
      @books = books
    end

    def self.load(hash)
      hand_cards = hash['hand'].map { |card| Card.load(card) }
      books = hash['books'].map { |book| book.map{ |card| Card.load(card) } }
      self.new(hash['id'], hash['name'], hand_cards, books)
    end

    def add_cards(cards)
      cards.each { |card| hand << card }
    end

    def hand_size = hand.size

    def book_size = books.size

    def get_cards_by_rank(rank)
      find_by_rank = ->(card) { card.rank == rank }

      cards_of_rank = hand.select(&find_by_rank)
      hand.delete_if(&find_by_rank)
      
      cards_of_rank
    end

    def make_book_if_possible(rank)
      cards = hand.select { it.rank == rank }

      if cards.count == 4
        self.hand -= cards
        books << GoFish::Book.new(cards)
      end
    end

    def highest_book_value
      highest_book_value = STARTING_BOOK_VALUE

      books.each do
        highest_book_value = it.value if it.value > highest_book_value
      end

      highest_book_value
    end
  end
end