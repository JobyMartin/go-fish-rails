module CrazyEights
  class Player

    attr_accessor :hand

    def initialize(id, hand = [])
      @id = id
      @hand = hand
    end

    def add_cards(cards)
      cards.each { |card| hand << card }
    end
  end
end