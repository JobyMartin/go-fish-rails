class UsersController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  def new
  end

  def create
    user = User.new(user_params)
    if user.save
      start_new_session_for(user)
      redirect_to root_path
    else
      flash.now[:alert] = 'Invalid signup'
      render :new
    end
  end

  def show
  end

  private

  def user_params
    params.permit(:email_address, :password, :confirm_password)
  end
end
