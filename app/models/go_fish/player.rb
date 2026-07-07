module GoFish
  class Player
    attr_reader :name
    attr_accessor :hand

    def initialize(name = 'Fisher')
      @name = name
      @hand = []
    end

    def self.load(hash)
      self.new
    end

    def add_cards(cards)
      cards.each { |card| hand << card }
    end
  end
end