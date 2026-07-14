
class GamesController < ApplicationController
  def index
    @user = Current.session.user
    @games = Game.all
  end

  def new
    @game = Game.new
  end

  def create
    @game = Game.new(game_params)
    @player = @game.players.new(user: Current.session.user)
    @player.save
    
    if @game.save
      redirect_to game_path(@game)
    else
      render :new
    end
  end

  def show
    @game = Game.find(params[:id])
    @started = @game.started_at.present?
    return unless @started
    @go_fish_game = @game.go_fish
    @current_player = @go_fish_game.find_player(Current.session.user.id)
    @opponents = @go_fish_game.players - [@current_player]
  end

  def start
    @game = Game.find(params[:id])
    @game.start
    redirect_to game_path(@game)
  end

  def history
    @user_games = Current.session.user.games
  end
  def play
    @game = Game.find(params[:id])

    redirect_to winner_game_path(@game) and return if @game.go_fish.game_over?

    @game.play_go_fish(params[:play_turn][:player].to_i, params[:play_turn][:rank])

    @game.save!
    redirect_to game_path(@game)
  end

  def winner
    @game = Game.find(params[:id])
    @winner = @game.go_fish.winner
  end

  private

  def game_params
    data = params.require(:game).permit(:name, :game_type)
    data[:game_type] = data[:game_type].parameterize(separator: '_')
    data
  end
end
