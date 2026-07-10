
class GamesController < ApplicationController
  def index
    @user = Current.session.user
    @games = Game.all
  end

  def new
    @game = Game.new
  end

  def create
    type = params[:game][:type]
    type_class = "#{type}Game".delete(' ').constantize
    @game = type_class.new(game_params)
    @player = @game.players.new(user: Current.session.user)

    if @game.save!
      redirect_to game_path(@game)
    else
      render :new
    end
  end

  def show
    @game = Game.find(params[:id])
    @started = @game.started_at.present?
    return unless @started
    @implementation = @game.game_state
    @current_player = @implementation.find_player(Current.session.user.id)
    @opponents = @implementation.players - [@current_player]
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

    redirect_to winner_game_path(@game) and return if @game.game_state.game_over?

    @game.play_turn(params[:play_turn][:player].to_i, params[:play_turn][:rank])

    @game.save!
    redirect_to game_path(@game)
  end

  def winner
    @game = Game.find(params[:id])
    @winner = @game.game_state.winner
  end

  private

  def game_params
    params.require(:game).permit(:name, :game_type)
  end
end
