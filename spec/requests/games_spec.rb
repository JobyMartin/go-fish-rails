require 'rails_helper'

# There is no GET that starts a game, so the crafted-POST bypass can't be reached from a
# system spec — this is the rare case docs/testing.md allows a request spec for.
RSpec.describe 'Games', type: :request do
  let(:user) { create(:user) }
  let(:game) { create(:game) }

  before do
    create(:player, user:, game:)
    post session_path, params: { session: { email_address: user.email_address, password: user.password } }
  end

  describe 'POST start' do
    it 'refuses to start a game below the minimum player count' do
      expect { post start_game_path(game) }.not_to change { game.reload.started_at }
    end

    it 'says why it refused' do
      post start_game_path(game)
      expect(flash[:alert]).to eq Game::NOT_ENOUGH_PLAYERS_MESSAGE
    end

    it 'sends them back to the waiting room' do
      post start_game_path(game)
      expect(response).to redirect_to game_path(game)
    end

    it 'starts the game once the table has enough players' do
      create(:player, game:)
      expect { post start_game_path(game) }.to change { game.reload.started_at }.from(nil)
    end
  end
end
