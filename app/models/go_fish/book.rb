module GoFish
  class Book
    attr_reader :cards
  
    def initialize(cards)
      @cards = cards
    end
  
    def value = cards.first.value
    
    def rank = cards.first.rank
  end
end
