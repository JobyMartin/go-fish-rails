module GoFish
  class Book
    attr_reader :cards
  
    def initialize(cards)
      @cards = cards
    end
  
    def value = cards.first.value
    
    def rank = cards.first.rank

    def self.load(hash)
      hash['cards'].is_a?(Array) ? hash_cards = hash['cards'] : hash_cards = [hash['cards']]
      cards = hash_cards.map do |card|
        Card.load(card)
      end
      self.new(cards)
    end
  end
end
