require 'rails_helper'

RSpec.describe Rummy::RoundResult, type: :model do
  let(:current_player) { Rummy::Player.new(0, 'Joby') }
  let(:hearts_run) { [ Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts') ] }

  describe '#feed_lines' do
    context 'when the player took from the discard pile' do
      it 'names the card and where it came from' do
        result = described_class.new(move: :took, current_player:, cards: [ Card.new('9', 'Diamonds') ])

        expect(result.feed_lines.first.text).to eq 'Joby took a 9 of Diamonds from the discard pile'
      end

      it 'has a single action line' do
        result = described_class.new(move: :took, current_player:, cards: [ Card.new('9', 'Diamonds') ])

        expect(result.feed_lines.map(&:role)).to eq [ :action ]
      end
    end

    context 'when the player melded' do
      it 'names every card in the meld' do
        result = described_class.new(move: :melded, current_player:, cards: hearts_run)

        expect(result.feed_lines.first.text).to eq 'Joby melded 3 of Hearts, 4 of Hearts, 5 of Hearts'
      end

      it 'has a single action line' do
        result = described_class.new(move: :melded, current_player:, cards: hearts_run)

        expect(result.feed_lines.map(&:role)).to eq [ :action ]
      end
    end

    context 'when the player laid off' do
      it 'names the card without naming the meld' do
        result = described_class.new(move: :laid_off, current_player:, cards: [ Card.new('6', 'Hearts') ])

        expect(result.feed_lines.first.text).to eq 'Joby laid off 6 of Hearts'
      end

      it 'has a single action line' do
        result = described_class.new(move: :laid_off, current_player:, cards: [ Card.new('6', 'Hearts') ])

        expect(result.feed_lines.map(&:role)).to eq [ :action ]
      end
    end

    context 'when the player discarded' do
      it 'names the discarded card' do
        result = described_class.new(move: :discarded, current_player:, cards: [ Card.new('7', 'Spades') ])

        expect(result.feed_lines.first.text).to eq 'Joby discarded a 7 of Spades'
      end

      it 'has a single action line' do
        result = described_class.new(move: :discarded, current_player:, cards: [ Card.new('7', 'Spades') ])

        expect(result.feed_lines.map(&:role)).to eq [ :action ]
      end
    end
  end

  describe '#feed_lines when the move empties the hand' do
    it 'announces the win after a discard' do
      result = described_class.new(
        move: :discarded, current_player:, cards: [ Card.new('7', 'Spades') ], going_out: true
      )

      expect(result.feed_lines.last.text).to eq 'Joby went out and won!'
    end

    it 'announces the win after a meld' do
      result = described_class.new(move: :melded, current_player:, cards: hearts_run, going_out: true)

      expect(result.feed_lines.last.text).to eq 'Joby went out and won!'
    end

    it 'announces the win after a lay off' do
      result = described_class.new(
        move: :laid_off, current_player:, cards: [ Card.new('6', 'Hearts') ], going_out: true
      )

      expect(result.feed_lines.last.text).to eq 'Joby went out and won!'
    end

    it 'keeps the action line in front of the win line' do
      result = described_class.new(move: :melded, current_player:, cards: hearts_run, going_out: true)

      expect(result.feed_lines.map(&:text).first).to eq 'Joby melded 3 of Hearts, 4 of Hearts, 5 of Hearts'
    end

    it 'styles the win line as a game response' do
      result = described_class.new(move: :melded, current_player:, cards: hearts_run, going_out: true)

      expect(result.feed_lines.map(&:role)).to eq [ :action, :game_response ]
    end
  end

  describe '.load' do
    let(:hash) do
      { 'move' => 'melded', 'current_player' => current_player.as_json, 'cards' => hearts_run.map(&:as_json) }
    end

    it 'rebuilds the move as a symbol even though the blob stores a string' do
      expect(described_class.load(hash).move).to eq :melded
    end

    it 'rebuilds the cards' do
      expect(described_class.load(hash).cards).to eq hearts_run
    end

    it 'rebuilds the current player' do
      expect(described_class.load(hash).current_player.name).to eq 'Joby'
    end

    it 'rebuilds whether the player went out' do
      loaded = described_class.load(hash.merge('going_out' => true))

      expect(loaded.going_out).to eq true
    end

    it 'narrates a loaded result the same as a built one' do
      expect(described_class.load(hash).feed_lines.first.text)
        .to eq 'Joby melded 3 of Hearts, 4 of Hearts, 5 of Hearts'
    end
  end
end
