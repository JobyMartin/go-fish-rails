module Rummy
  class HandSorter
    def initialize(cards)
      @cards = cards
    end

    def sorted
      ordered_groups.flatten + suit_rank_sort(@cards - ordered_groups.flatten)
    end

    private

    def ordered_groups
      @ordered_groups ||= (sets + runs).sort_by { |group| group_key(group) }
    end

    def sets
      @cards.group_by(&:rank).values.select { it.size >= 2 }.map { suit_rank_sort(it) }
    end

    def runs
      Card::SUITS.flat_map { |suit| runs_in_suit(unset_cards.select { it.suit == suit }) }
    end

    def unset_cards
      @cards - sets.flatten
    end

    def runs_in_suit(cards)
      ordered = cards.sort_by { Meld::RANK_ORDER.index(it.rank) }
      ordered.chunk_while { |a, b| consecutive?(a, b) }.select { it.size >= 2 }.to_a
    end

    def consecutive?(a, b)
      Meld::RANK_ORDER.index(b.rank) - Meld::RANK_ORDER.index(a.rank) == 1
    end

    def group_key(group) = [ -group.size, Card::SUITS.index(group.first.suit), Card::RANKS.index(group.first.rank) ]

    def suit_rank_sort(cards)
      cards.sort_by { |card| [ Card::SUITS.index(card.suit), Card::RANKS.index(card.rank) ] }
    end
  end
end
