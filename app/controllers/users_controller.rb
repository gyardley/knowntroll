class UsersController < ApplicationController

  before_filter :must_be_logged_in, only: [ :email, :decline ]

  def email
    if params[:email]
      current_user.email = params[:email]
      current_user.save
    end
    flash[:success] = "Thank you for sharing your email with KnownTroll! We'll be careful with it."
    redirect_to lists_path
  end

  def decline
    current_user.declined = true
    current_user.save
    flash[:success] = "Got it. We won't ask for your email again."
    redirect_to lists_path
  end
end
