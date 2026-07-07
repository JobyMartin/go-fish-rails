module GoFish
  class Player
    attr_reader :name
    attr_accessor :hand

    def initialize(name = 'Fisher', hand = [])
      @name = name
      @hand = hand
    end

    def self.load(hash)
      hand_cards = hash['hand'].map { |card| Card.load(card) }
      self.new(hash['name'], hand_cards)
    end

    def add_cards(cards)
      cards.each { |card| hand << card }
    end
  end
end