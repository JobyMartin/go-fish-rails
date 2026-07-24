module Rummy
  class Player
    attr_reader :id, :name
    attr_accessor :hand

    def initialize(id, name = "Rummy Player", hand = [], melded = false)
      @id = id
      @name = name
      @hand = hand
      @melded = melded
    end

    def melded? = @melded

    def mark_melded!
      @melded = true
    end

    def add_cards(cards)
      cards.each { |card| hand << card }
    end

    def sort_hand!
      hand.sort_by! { |card| [ Card::SUITS.index(card.suit), Card::RANKS.index(card.rank) ] }
    end

    def smart_sort_hand!
      self.hand = HandSorter.new(hand).sorted
    end

    def self.load(hash)
      return nil if hash.nil?

      hand_cards = hash["hand"].map { |card| Card.load(card) }
      self.new(hash["id"], hash["name"], hand_cards, hash["melded"] || false)
    end
  end
end
