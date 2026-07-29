module CrazyEights
  class Player
    attr_reader :id, :name
    attr_accessor :hand

    def initialize(id, name = "Crazy Eighter", hand = [])
      @id = id
      @name = name
      @hand = hand
    end

    def add_cards(cards)
      cards.each { |card| hand << card }
    end

    def self.load(hash)
      hand_cards = hash["hand"].map { |card| Card.load(card) } unless hash.nil?
      self.new(hash["id"], hash["name"], hand_cards) unless hash.nil?
    end
  end
end
