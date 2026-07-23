
class GamesController < ApplicationController
  before_action :set_game, only: %i[show start play winner]
  before_action :require_participation, only: %i[show start play winner]

  def index
    @user = Current.session.user
    @games = Game.all
  end

  def new
    @game = Game.new
    render layout: "modal"
  end

  def create
    type_class = Game.playable_class(params[:game][:type])
    @game = type_class.new(game_params)
    @player = @game.players.new(user: Current.session.user)

    if @game.save!
      redirect_to game_path(@game)
    else
      render :new, status: :unprocessable_content, layout: "modal"
    end
  end

  def show
    @started = @game.started_at.present?
    return unless @started
    @implementation = @game.game_state
    @current_player = @implementation.find_player(Current.session.user.id)
    @opponents = @implementation.players - [ @current_player ]
  end

  def start
    @game.start
    redirect_to game_path(@game)
  end

  def history
    @user_games = Current.session.user.games
  end
  def play
    redirect_to winner_game_path(@game) and return if @game.game_state.game_over?

    @game.play_turn(play_turn_params)

    @game.save!
    redirect_to game_path(@game)
  end

  def winner
    @winner = @game.game_state.winner
  end

  private

  def set_game
    @game = Game.find(params[:id])
  end

  def require_participation
    return if @game.users.include?(Current.session.user)

    redirect_to games_path, alert: "You're not in that game."
  end

  def play_turn_params
    params.require(:play_turn).permit(:player, :rank, :suit, :move, :source, :meld_id, :card_id, card_ids: [])
  end

  def game_params
    params.require(:game).permit(:name)
  end
end
