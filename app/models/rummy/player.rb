module Rummy
  class Player
    attr_reader :id, :name
    attr_accessor :hand

    def initialize(id, name = "Rummy Player", hand = [])
      @id = id
      @name = name
      @hand = hand
    end

    def add_cards(cards)
      cards.each { |card| hand << card }
    end

    def self.load(hash)
      return nil if hash.nil?

      hand_cards = hash["hand"].map { |card| Card.load(card) }
      self.new(hash["id"], hash["name"], hand_cards)
    end
  end
end
