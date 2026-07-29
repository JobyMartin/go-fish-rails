require 'rails_helper'

RSpec.describe 'Games', type: :system do
  let(:user) { create(:user) }
  let(:user2) { create :user }

  before do
    sign_in(user)
  end

  it 'shows the games index' do
    visit games_path
    expect(page).to have_content 'Your Games'
    expect(page).to have_content 'All Games'
  end

  it 'shows the history' do
    visit games_history_path
    expect(page).to have_content 'Your History'
  end

  it 'allows user to go to game creation form' do
    click_on 'New Game'
    expect(page).to have_content 'Create Game'
  end

  context 'when a game is created' do
    it 'adds to the database' do
      expect do
        create_game
      end.to change(Game, :count).by 1
    end

    it 'sends them to the show page' do
      game_name = "Start game"
      create_game(game_name)
      expect(page).to have_content game_name
    end
  end

  context 'when a new game is created' do
    let!(:game_name1) { "Tony Stark's Game" }
    let!(:game_name2) { "Steve Rogers' Game" }
    let!(:game) { create(:game, name: game_name1) }
    let!(:player) { create(:player, user:, game:) }
    let!(:game2) { create(:game, name: game_name2) }

    before do
      # create_game(game_name)
      visit games_path
    end

    it 'updates the games page correctly' do
      within data_test('your-games') do
        expect(page).to have_content game_name1
      end

      within data_test('all-games') do
        expect(page).not_to have_content game_name1
        expect(page).to have_content game_name2
      end
    end
  end

  context 'when user creates a go fish game' do
    before do
      visit games_path
      click_on 'New Game'
      fill_in 'Name', with: 'Toast'
    end

    it 'offers every registry entry in the type select' do
      expect(page).to have_select('Type', with_options: Game.playable_types.values)
    end

    it 'creates a GoFishGame' do
      select 'Go Fish', from: 'Type'
      expect do
        click_on 'Create Game'
      end.to change(Game, :count).by 1

      expect(Game.last).to be_a GoFishGame
    end

    context 'when the user views the game page' do
      before do
        select 'Go Fish', from: 'Type'
        click_on 'Create Game'
      end

      it 'shows the go fish game view' do
        click_on 'Start game'
        expect(page).to have_css(data_test('game-aside'))
        expect(Game.last.game_state).to be_present
      end
    end
  end

  context 'when user creates a crazy eights game' do
    let(:game_name) { 'Toast' }

    before do
      visit games_path
      click_on 'New Game'
      fill_in 'Name', with: game_name
    end

    it 'creates a CrazyEightsGame' do
      select 'Crazy Eights', from: 'Type'
      expect do
        click_on 'Create Game'
      end.to change(Game, :count).by 1

      expect(Game.last).to be_a CrazyEightsGame
    end

    context 'when the user views the game page' do
      before do
        select 'Crazy Eights', from: 'Type'
        click_on 'Create Game'
      end

      it 'shows the crazy eights game view' do
        click_on 'Start game'
        expect(page).to have_css data_test('game')
        expect(Game.last.game_state).to be_present
      end

      it 'renders the play form with no opponent select' do
        click_on 'Start game'
        expect(page).to have_button 'Place card'
        expect(page).to have_no_select 'Player'
      end

      context 'when the user starts the game' do
        before do
          click_on 'Start game'
        end

        it 'shows the game name' do
          expect(page).to have_content game_name
        end

        it 'displays the players' do
          within(data_test('game-board')) do
            expect(page).to have_css(data_test('accordion'), count: 1)
          end
        end

        it 'displays the discard pile' do
          within data_test('game-aside') do
            expect(page).to have_css data_test('card')
          end
        end

        context 'when the user plays a turn' do
          it 'shows the turn in the turn results' do
            game = Game.last
            hand_before = game.game_state.current_player.hand.size
            discard_before = game.game_state.william.cards.size

            expect { click_on 'Place card' }
              .to change { game.reload.game_state.round_results.size }.by(1)

            within data_test('feed-content') do
              expect(page).to have_css(data_test('feed-action'), count: 1)
            end

            state = game.game_state
            expect(state.current_player.hand.size).to eq hand_before - 1
            expect(state.william.cards.size).to eq discard_before + 1
          end
        end
      end
    end
  end

  context 'when user creates a rummy game' do
    let(:game_name) { 'Toast' }
    let(:went_out_line) { /went out/i }
    let(:took_king_of_clubs_line) { /took a K of Clubs from the discard pile/i }
    let(:melded_hearts_run_line) { /melded 3 of Hearts, 4 of Hearts, 5 of Hearts/i }
    let(:discarded_two_of_clubs_line) { /discarded a 2 of Clubs/i }
    let(:laid_off_six_of_hearts_line) { /laid off 6 of Hearts/i }

    before do
      click_on 'New Game'
      fill_in 'Name', with: game_name
    end

    it 'creates a RummyGame' do
      select 'Rummy', from: 'Type'
      expect do
        click_on 'Create Game'
      end.to change(Game, :count).by 1

      expect(Game.last).to be_a RummyGame
    end

    context 'when the user starts the game' do
      before { start_rummy_game }

      it 'shows the game board' do
        expect(page).to have_css data_test('game')
      end

      it 'starts with no melds on the table' do
        within data_test('game-board') do
          expect(page).to have_no_css data_test('meld')
        end
      end

      it 'shows the deck and discard piles' do
        within data_test('game-controls') do
          expect(page).to have_css data_test('pile'), count: 2
        end
      end

      it 'shows the current player hand' do
        within data_test('game-hand') do
          expect(page).to have_css data_test('card'), minimum: 1
        end
      end

      it 'shows the players panel' do
        within data_test('game-aside') do
          expect(page).to have_css data_test('player-row'), minimum: 1
        end
      end

      it 'shows the game feed drawer tab' do
        expect(page).to have_css data_test('feed-tab')
      end
    end

    context 'when the user opens the game feed', :js do
      before { start_rummy_game }

      it 'slides the game feed drawer onto the screen' do
        click_button 'Game Feed'

        expect(page).to have_css 'body[data-feed-open="true"]'
      end

      it 'shows an empty state before any moves have happened' do
        click_button 'Game Feed'

        within data_test('feed-content') do
          expect(page).to have_content 'No moves yet'
        end
      end

      it 'closes the drawer when the close button is clicked' do
        click_button 'Game Feed'
        find('[aria-label="Close game feed"]').click

        expect(page).to have_css 'body[data-feed-open="false"]'
      end
    end

    context 'when the user takes a full turn', :js do
      before do
        start_rummy_game_with_state do |state|
          state.current_player.hand = [
            Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts'), Card.new('2', 'Clubs')
          ]
          state.discard_pile = [ Card.new('K', 'Clubs') ]
        end
      end

      it 'drawing from the deck adds a card to the hand' do
        before_count = hand_card_count
        deck_before = Game.last.game_state.deck.cards_left

        click_button 'Draw deck'

        expect(page).to have_css("#{data_test('game-hand')} #{data_test('card')}", count: before_count + 1)

        state = Game.last.game_state
        expect(state.current_player.hand.size).to eq before_count + 1
        expect(state.deck.cards_left).to eq deck_before - 1
        expect(state.drawn_this_turn).to eq true
      end

      it 'discarding a card ends the turn and shows the move in the game feed' do
        draw_and_discard('2 Clubs')

        within data_test('feed-content') do
          expect(page).to have_css(data_test('feed-action'), count: 1)
        end

        state = Game.last.game_state
        expect(state.current_player.hand).not_to include(Card.new('2', 'Clubs'))
        expect(state.discard_pile.last).to eq Card.new('2', 'Clubs')
        expect(state.drawn_this_turn).to eq false
      end

      it 'shows the discard message in the feed once the drawer is opened' do
        draw_and_discard('2 Clubs')
        click_button 'Game Feed'

        within data_test('feed-content') do
          expect(page).to have_css data_test('feed-action'), text: discarded_two_of_clubs_line
        end

        expect(Game.last.game_state.round_results.last.cards.first).to eq Card.new('2', 'Clubs')
      end

      it 'taking from the discard pile shows the move in the game feed' do
        hand_before = hand_card_count

        click_button 'Take discard'

        click_button 'Game Feed'

        within data_test('feed-content') do
          expect(page).to have_css data_test('feed-action'), text: took_king_of_clubs_line
        end

        state = Game.last.game_state
        expect(state.current_player.hand.size).to eq hand_before + 1
        expect(state.current_player.hand).to include(Card.new('K', 'Clubs'))
        expect(state.discard_pile).to be_empty
      end

      it 'melding a valid run from the hand adds it to the table' do
        melds_before = all(data_test('meld')).count

        meld_hearts_run

        within data_test('game-board') do
          expect(page).to have_css data_test('meld'), count: melds_before + 1
        end

        state = Game.last.game_state
        expect(state.melds.last.cards).to contain_exactly(
          Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts')
        )
        expect(state.current_player.hand).not_to include(Card.new('3', 'Hearts'))
        expect(state.current_player.hand).not_to include(Card.new('4', 'Hearts'))
        expect(state.current_player.hand).not_to include(Card.new('5', 'Hearts'))
      end

      it 'shows the melded cards in the feed without announcing a win' do
        meld_hearts_run
        click_button 'Game Feed'

        within data_test('feed-content') do
          expect(page).to have_css data_test('feed-action'), text: melded_hearts_run_line
          expect(page).to have_no_css data_test('feed-game-response')
        end
      end

      it 'shows an error message when melding an invalid combination' do
        click_button 'Draw deck'
        select_hand_card('3 Hearts')
        select_hand_card('4 Hearts')
        select_hand_card('2 Clubs')
        click_button 'Meld selected'

        within(data_test('flash')) { expect(page).to have_text("That's not a valid set or run.") }
        expect(page).to have_css '.alert--danger'
        expect(all(data_test('meld'))).to be_empty
      end

      it "shows an error when discarding the card just taken from the discard pile" do
        click_button 'Take discard'
        select_hand_card('K Clubs')
        click_button 'Discard selected'

        within(data_test('flash')) { expect(page).to have_text('you just took from the discard pile') }
      end
    end

    context 'when the user lays off before melding', :js do
      before do
        start_rummy_game_with_state do |state|
          state.melds = [ Rummy::Meld.new([ Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts') ]) ]
          state.current_player.hand = [ Card.new('6', 'Hearts') ]
          state.drawn_this_turn = true
        end
      end

      it 'shows an error telling them to meld first' do
        select_hand_card('6 Hearts')
        click_button 'Lay off here'

        within(data_test('flash')) { expect(page).to have_text('lay down a meld') }
      end
    end

    context 'when the user sorts their hand' do
      before do
        start_rummy_game_with_state do |state|
          state.current_player.hand = [
            Card.new('K', 'Clubs'), Card.new('A', 'Diamonds'), Card.new('2', 'Hearts')
          ]
        end
      end

      it 'reorders the hand by suit then rank' do
        click_button 'Sort by suit'

        expect(hand_card_prefixes).to eq %w[a_diamonds 2_hearts k_clubs]

        expect(Game.last.game_state.current_player.hand).to eq [
          Card.new('A', 'Diamonds'), Card.new('2', 'Hearts'), Card.new('K', 'Clubs')
        ]
      end
    end

    context 'when the user smart sorts their hand' do
      before do
        start_rummy_game_with_state do |state|
          state.current_player.hand = [
            Card.new('2', 'Hearts'), Card.new('5', 'Clubs'), Card.new('5', 'Diamonds')
          ]
        end
      end

      it 'groups the set in the making before the rest of the hand' do
        click_button 'Smart sort'

        expect(hand_card_prefixes).to eq %w[5_diamonds 5_clubs 2_hearts]

        expect(Game.last.game_state.current_player.hand).to eq [
          Card.new('5', 'Diamonds'), Card.new('5', 'Clubs'), Card.new('2', 'Hearts')
        ]
      end
    end

    context 'when the user selects a hand card', :js do
      before do
        start_rummy_game_with_state { |state| state.current_player.hand = [ Card.new('2', 'Clubs') ] }

        click_button 'Draw deck'
      end

      it 'highlights the card as selected' do
        select_hand_card('2 Clubs')

        expect(find("[data-card='2 Clubs']")['data-selected']).to eq 'true'
      end

      it 'enables the discard button once a card is selected' do
        select_hand_card('2 Clubs')

        expect(page).to have_button 'Discard selected', disabled: false
      end

      it 'deselects the card on a second click, disabling the discard button' do
        select_hand_card('2 Clubs')
        select_hand_card('2 Clubs')

        expect(page).to have_button 'Discard selected', disabled: true
      end
    end

    context 'when the user selects fewer cards than a meld needs', :js do
      before do
        start_rummy_game_with_state do |state|
          state.current_player.hand = [
            Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts')
          ]
          state.drawn_this_turn = true
        end
      end

      it 'keeps the meld button disabled with one card selected' do
        select_hand_card('3 Hearts')

        expect(page).to have_button 'Meld selected', disabled: true
      end

      it 'keeps the meld button disabled with two cards selected' do
        select_hand_card('3 Hearts')
        select_hand_card('4 Hearts')

        expect(page).to have_button 'Meld selected', disabled: true
      end

      it 'enables the meld button once three cards are selected' do
        select_hand_card('3 Hearts')
        select_hand_card('4 Hearts')
        select_hand_card('5 Hearts')

        expect(page).to have_button 'Meld selected', disabled: false
      end
    end

    context 'when the user goes out', :js do
      before do
        start_rummy_game_with_state do |state|
          state.current_player.hand = [
            Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts')
          ]
        end
      end

      it 'ends the game once the last card is discarded' do
        meld_hearts_run
        discard_only_hand_card

        expect(Game.last.game_state.game_over?).to eq true
      end

      it 'shows the winner screen on a later visit' do
        meld_hearts_run
        discard_only_hand_card

        visit winner_game_path(Game.last)

        expect(page).to have_content 'The winner is'
      end

      it 'shows a styled going-out message in the game feed' do
        meld_hearts_run
        discard_only_hand_card
        click_button 'Game Feed'

        within data_test('feed-content') do
          expect(page).to have_css data_test('feed-game-response'), text: went_out_line
        end
      end
    end

    context 'when the user melds out', :js do
      before do
        start_rummy_game_with_state do |state|
          state.current_player.hand = [
            Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts')
          ]
          state.drawn_this_turn = true
        end
      end

      it 'shows the meld and a styled going-out message in the game feed' do
        meld_selected_hearts_run
        click_button 'Game Feed'

        within data_test('feed-content') do
          expect(page).to have_css data_test('feed-action'), text: melded_hearts_run_line
          expect(page).to have_css data_test('feed-game-response'), text: went_out_line
        end
      end

      it 'ends the game without a discard' do
        meld_selected_hearts_run

        expect(page).to have_no_css "#{data_test('game-hand')} #{data_test('card')}"
        expect(Game.last.game_state.game_over?).to eq true
      end
    end

    context 'when the user lays off after melding', :js do
      before do
        start_rummy_game_with_state do |state|
          state.melds = [ Rummy::Meld.new([ Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts') ]) ]
          state.current_player.mark_melded!
          state.current_player.hand = [ Card.new('6', 'Hearts'), Card.new('K', 'Spades') ]
          state.drawn_this_turn = true
        end
      end

      it 'shows the laid off card in the game feed' do
        lay_off_hand_card('6 Hearts')
        click_button 'Game Feed'

        within data_test('feed-content') do
          expect(page).to have_css data_test('feed-action'), text: laid_off_six_of_hearts_line
        end
      end

      it 'does not announce a win while cards remain in hand' do
        lay_off_hand_card('6 Hearts')
        click_button 'Game Feed'

        within data_test('feed-content') do
          expect(page).to have_no_css data_test('feed-game-response')
        end
      end
    end

    context 'when the user lays off their last card', :js do
      before do
        start_rummy_game_with_state do |state|
          state.melds = [ Rummy::Meld.new([ Card.new('3', 'Hearts'), Card.new('4', 'Hearts'), Card.new('5', 'Hearts') ]) ]
          state.current_player.mark_melded!
          state.current_player.hand = [ Card.new('6', 'Hearts') ]
          state.drawn_this_turn = true
        end
      end

      it 'shows the lay off and a styled going-out message in the game feed' do
        lay_off_hand_card('6 Hearts')
        click_button 'Game Feed'

        within data_test('feed-content') do
          expect(page).to have_css data_test('feed-action'), text: laid_off_six_of_hearts_line
          expect(page).to have_css data_test('feed-game-response'), text: went_out_line
        end
      end

      it 'ends the game without a discard' do
        lay_off_hand_card('6 Hearts')

        expect(page).to have_no_css "#{data_test('game-hand')} #{data_test('card')}"
        expect(Game.last.game_state.game_over?).to eq true
      end
    end
  end

  context 'when there is an open game' do
    let(:game_content) { "Start game" }
    let!(:game) { create(:game) }

    before do
      visit games_path
    end

    it 'allows them to join' do
      expect do
        click_on 'Join'
        expect(page).to have_current_path game_path(game)
        expect(page).to have_content game_content
      end.to change(Player, :count).by 1
      # that's kinda spicy
      expect(Player.last.game).to eq game
    end
  end

  context 'when user creates a game and views their games' do
    let(:game_name) { 'hippity hoppity this code is now my property' }
    before do
      create_game(name: game_name)
      visit games_path
    end

    it 'is listed under their games' do
      within data_test('your-games') do
        expect(page).to have_content game_name
      end
    end

    context 'when they view a game they are in' do
      before do
        click_on 'View'
      end
      it 'lets them in and shows the game' do
        unique_content = 'Start game'
        expect(page).to have_content unique_content
      end
    end
  end

  context 'when the player has played games' do
    let(:game_name) { "Joby's game" }
    let(:game_name1) { "Gabe's game" }

    before do
      create_game(game_name)
      create_game(game_name1)
      visit games_history_path
    end

    it 'displays those games' do
      expect(page).to have_content game_name
      expect(page).to have_content game_name1
    end
  end

  context 'when the user clicks to start a game' do
    let!(:game) { create :game }
    let!(:player) { create(:player, user:, game:) }

    it 'starts a game' do
      visit game_path(game)
      click_on 'Start game'
      expect(game.reload.game_state).to be_present
    end

    it 'a timer is there' do
      visit game_path(game)
      click_on 'Start game'
      expect(page).to have_css data_test('timer')
    end

    xit 'takes the turn for them if they wait 10 seconds' do
      visit game_path(game)
      click_on 'Start game'

      expect(page).to have_button('Ask for a card', disabled: false)

      expect(page).to have_button('Ask for a card', disabled: true, wait: 11)
    end
  end

  context 'when the user plays a turn' do
    let!(:game) { create :game }
    let!(:player) { create(:player, user:, game:) }
    let!(:player2) { create(:player, user: user2, game:) }
    # let(:session1) { Capybara::Session.new(:rack_test, Rails.application) }
    # let(:session2) { Capybara::Session.new(:rack_test, Rails.application) }

    context 'when the rank in question is in a hand' do
      starting_hand_size = 1

      before do
        game.start
        game.game_state.players.each do |player|
          player.hand = [ Card.new('A') ]
        end
        game.save!
      end

      it 'exchanges the cards between players' do
        visit game_path(game)

        expect { click_on 'Ask for a card' }
          .to change { game.reload.game_state.round_results.size }.by(1)

        expect(page).to have_content(starting_hand_size * 2)
        state = game.game_state
        expect(state.find_player(user.id).hand.size).to eq starting_hand_size * 2
        expect(state.find_player(user2.id).hand).to be_empty
      end
    end

    context 'when the card makes a book' do
      asking_player_hand = [ Card.new ]
      answering_player_hand = [ Card.new, Card.new, Card.new ]

      before do
        game.start
        game.game_state.players.first.hand = asking_player_hand
        game.game_state.players.last.hand = answering_player_hand
        game.save!
      end

      it 'makes a book' do
        visit game_path(game)

        expect { page.click_on 'Ask for a card' }
          .to change { game.reload.game_state.players.first.books.size }.by(1)

        within data_test('books') do
          expect(page).to have_css('img')
        end

        state = game.game_state
        expect(state.players.first.hand).to be_empty
        expect(state.players.first.books.first.cards.size).to eq(asking_player_hand.size + answering_player_hand.size)
        expect(state.players.last.hand).to be_empty
      end
    end

    context 'when the rank in question is not in a hand' do
      it 'goes fishing'
    end

    context 'when it is not the current users turn' do
      before do
        game.start
        game.game_state.current_player_index = 1
        game.save!
      end

      it 'the ask button is disabled' do
        visit game_path(game)
        expect(page).to have_button('Ask for a card', disabled: true)
      end
    end
  end

  context 'when the user is not a participant' do
    let!(:game) { create(:game) }
    let!(:player) { create(:player, user: user2, game:) }

    it 'redirects to the lobby with a flash from the game page' do
      visit game_path(game)

      expect(page).to have_current_path(games_path)
      expect(page).to have_content "You're not in that game."
    end

    it 'shows no game content on the redirect' do
      visit game_path(game)

      expect(page).to have_no_content 'Start game'
    end

    it 'redirects to the lobby from the winner screen' do
      visit winner_game_path(game)

      expect(page).to have_current_path(games_path)
      expect(page).to have_content "You're not in that game."
    end
  end

  context 'when a go fish game is over' do
    let!(:game) { create :game }
    let!(:player) { create(:player, user:, game:) }
    let!(:player2) { create(:player, user: user2, game:) }

    before do
      game.start
      game.game_state.players.each { it.hand = [] }
      game.game_state.deck.cards = []
      game.save!
    end

    it 'shows the winner screen' do
      visit winner_game_path(game)
      expect(page).to have_content 'winner'
    end
  end

  context 'when a crazy eights game is over' do
    let!(:game) { create(:game, type: 'CrazyEightsGame') }
    let!(:player) { create(:player, user:, game:) }
    let!(:player2) { create(:player, user: user2, game:) }

    before do
      game.start
      game.game_state.players.first.hand = []
      game.save!
    end

    it 'shows the winner screen' do
      visit winner_game_path(game)
      expect(page).to have_content 'winner'
    end
  end
end
