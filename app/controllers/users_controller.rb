class UsersController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  def new
  end

  def create
  end
end
