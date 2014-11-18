class SessionsController < ApplicationController

  def create
    logger.info env['omniauth.auth']
    user = User.from_omniauth(env['omniauth.auth'])

    session[:user_id] = user.id
    flash[:success] = "Great to see you! You've successfully signed into KnownTroll."
    redirect_to lists_path
  end

  def failure
    flash[:error] = "Hmmm... something went wrong with your Twitter signin. Please try again."
    redirect_to root_path
  end

  def destroy
    session[:user_id] = nil
    flash[:success] = "You've successfully signed out of KnownTroll. See you later!"
    redirect_to root_path
  end
end
