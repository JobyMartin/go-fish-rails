module GoFish
  class Player
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
  end
end