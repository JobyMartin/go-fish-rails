class UsersController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  def new
    @user = User.new
  end

  def edit
    @user = User.find(params[:id])

    render layout: 'modal'
  end

  def update
    @user = User.find(params[:id])
    if @user.update(update_params)
      redirect_to users_show_path(@user)
    else
      render :edit, status: :unprocessable_content, layout: 'modal'
    end
  end

  def turbo_fetch
    @user = User.new(update_params)
  end

  def create
    @user = User.new(user_params)
    if @user.save
      start_new_session_for(@user)
      redirect_to root_path
    else
      flash.now[:alert] = 'Invalid signup'
      render :new
    end
  end

  def show
  end

  private

  def update_params
    params.require(:user).permit(:country, :state)
  end

  def user_params
    params.require(:user).permit(:username, :email_address, :password, :confirm_password)
  end
end
