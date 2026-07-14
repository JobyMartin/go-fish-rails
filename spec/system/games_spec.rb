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
    expect(page).to have_content 'Your Go Fish History'
  end

  it 'allows user to go to game creation form' do
    click_on 'New Game'
    expect(page).to have_content 'Setup Game'
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
      within '[data-testid="your-games"]' do
        expect(page).to have_content game_name1
      end

      within '[data-testid="all-games"]' do
        expect(page).not_to have_content game_name1
        expect(page).to have_content game_name2
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
      within '[data-testid="your-games"]' do
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
      expect(game.reload.go_fish).to be_present
    end
  end

  context 'when the user plays a turn' do
    let!(:game) { create :game }
    let!(:player) { create(:player, user:, game:) }
    let!(:player2) { create(:player, user: user2, game:) }
    # let(:session1) { Capybara::Session.new(:rack_test, Rails.application) }
    # let(:session2) { Capybara::Session.new(:rack_test, Rails.application) }

    context 'when the rank in question is in a hand' do
      before do
        game.start
        game.go_fish.players.each do |player|
          player.hand = [GoFish::Card.new('A')]
        end
        game.save!
      end
      
      it 'exchanges the cards between players' do
        visit game_path(game)
        page.click_on 'Ask for a card'
        post_turn_card_count = '2'
        expect(page).to have_content post_turn_card_count
      end
    end

    context 'when the card makes a book' do
      before do
        game.start
        game.go_fish.players.first.hand = [GoFish::Card.new]
        game.go_fish.players.last.hand = [GoFish::Card.new, GoFish::Card.new, GoFish::Card.new]
        game.save!
      end

      it 'makes a book' do
        visit game_path(game)
        page.click_on 'Ask for a card'
        within '[data-testid="books"]' do
          expect(page).to have_css('img')
        end
      end
    end

    context 'when the rank in question is not in a hand' do
      it 'goes fishing'
    end

    context 'when it is not the current users turn' do
      before do
        game.start
        game.go_fish.current_player_index = 1
        game.save!
      end

      it 'the ask button is disabled' do
        visit game_path(game)
        expect(page).to have_button('Ask for a card', disabled: true)
      end
    end
  end

  context 'when the game is over', pending: 'broken and cannot figure out' do
    let!(:game) { create :game }
    let!(:player) { create(:player, user:, game:) }
    let!(:player2) { create(:player, user: user2, game:) }

    before do
      game.start

      game.go_fish.players.each do |player|
        player.hand = [GoFish::Card.new('A'), GoFish::Card.new('A')]
      end

      game.go_fish.deck.cards = []

      game.save!
    end

    it 'displays the winner' do
      visit game_path(game)
      click_on 'Ask for a card'
      expect(page).to have_content 'winner'
    end
  end

  # fcontext 'when the game ends' do
  #   let(:winner_message) { 'winner' }
  #   let(:name_message) { 'Name' }
  #   let!(:game) { create :game }
  #   let!(:player) { create(:player, user:, game:) }
  #   let!(:player2) { create(:player, user: user2, game:) }

  #   before do
  #     game.start
  #     binding.irb
      
  #     game.go_fish.deck.cards = []
  #     game.go_fish.players.first.hand = [GoFish::Card.new('A', 'Spades')]
  #     game.go_fish.players.last.hand = [GoFish::Card.new('A', 'Diamonds'), GoFish::Card.new('A', 'Hearts'), GoFish::Card.new('A', 'Clubs')]
      
  #     # game.players.first.books = [Book.new([Card.new('A', 'Spades')])]
  #     game.save!
  #     binding.irb
  #   end

  #   fit 'displays the winner' do
  #     visit game_path(game)
  #     page.click_on 'Ask for a card'
  #     expect(page).to have_content winner_message
  #   end

  #   xit 'resets the game' do
  #     session1.click_on "Play Again"
  #     expect(game.game_started?).to be false
  #     expect(session1).to have_content name_message
  #   end
  # end
end
