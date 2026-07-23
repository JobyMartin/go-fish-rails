module Rummy
  class Meld
    attr_accessor :cards

    def initialize(cards = [])
      @cards = cards
    end

    def self.load(hash)
      return nil if hash.nil?

      cards = hash["cards"].map { |card| Card.load(card) }
      self.new(cards)
    end
  end
end
