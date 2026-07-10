module CrazyEights
  class Player
    attr_reader :id
    attr_accessor :hand

    def initialize(id, hand = [])
      @id = id
      @hand = hand
    end

    def add_cards(cards)
      cards.each { |card| hand << card }
    end

    def self.load(hash)
      hand_cards = hash['hand'].map { |card| Card.load(card) } unless hash.nil?
      self.new(hash['id'], hand_cards) unless hash.nil?
    end
  end
end