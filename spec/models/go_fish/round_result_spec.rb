require 'rails_helper'

RSpec.describe GoFish::RoundResult, type: :model, pending: "change variables to reflect new stucture" do
  let(:game) { GoFish::Game.new }

  before do
    game.add_player('Joby')
    game.add_player('William')
  end

  let(:current_user) { game.current_player }
  let(:user_in_question) { game.players.last }
  let(:cards_exchanged) do
    [
      Card.new('A', 'Spades'),
      Card.new('K', 'Spades'),
      Card.new('Q', 'Spades')
    ]
  end
  let(:went_fishing) { false }
  let(:made_a_catch) { false }
  let(:rank_in_question) { 'A' }
  let(:round) { GoFish::RoundResult.new(current_user: current_user,
                               cards_exchanged: cards_exchanged,
                               user_in_question: user_in_question,
                               rank_in_question: rank_in_question,
                               went_fishing: went_fishing,
                               made_a_catch: made_a_catch) }

  it 'has a player taken from' do
    expect(round.user_taken_from).to be user_in_question
  end

  it 'has a player given to' do
    expect(round.user_given_to).to be current_user
  end

  it 'has cards exchanged' do
    expect(round.cards_exchanged).to be cards_exchanged
  end

  it 'tracks if the player went fishing' do
    expect(round.went_fishing).to be false
  end

  it 'tracks if the player made a catch' do
    expect(round.made_a_catch).to be false
  end

  describe '#for_current_player' do
    context 'player fishes' do
      let(:go_fish_regex) { /go fish/i }

      before do
        round.went_fishing = true
      end

      it 'returns go fish message' do
        expect(round.for_current_player).to include(match go_fish_regex)
      end
    end

    context 'player makes a catch' do
      let(:made_a_catch_regex) { /made a catch/i }

      before do
        round.made_a_catch = true
      end

      it 'returns made a catch message' do
        expect(round.for_current_player).to include(match made_a_catch_regex)
      end
    end

    context 'player gets cards from another player' do
      let(:message_regex) { /you took/i }

      it 'returns message for current player' do
        expect(round.for_current_player).to include(match message_regex)
      end
    end
  end

  describe '#for_other_players' do
    context 'player fishes' do
      let(:go_fish_regex) { /joby went fishing/i }

      before do
        round.went_fishing = true
      end

      it 'returns go fish message' do
        expect(round.for_other_players).to include(match go_fish_regex)
      end
    end

    context 'player makes a catch' do
      let(:made_a_catch_regex) { /joby made a catch/i }

      before do
        round.made_a_catch = true
      end

      it 'returns made a catch message' do
        expect(round.for_other_players).to include(match made_a_catch_regex)
      end
    end

    context 'player gets cards from another player' do
      let(:message_regex) { /joby took/i }

      it 'returns message for current player' do
        expect(round.for_other_players).to include(match message_regex)
      end
    end
  end
end
