class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  force_ssl

  helper_method :current_user

  def must_be_logged_in
    if !current_user
      flash[:error] = "Sorry, but you must be signed in to view that page."
      redirect_to root_path
    elsif !current_user.authorized?
      session[:user_id] = nil
      redirect_to root_path
    end
  end

  def must_be_logged_out
    redirect_to(lists_path) if current_user
  end

  def must_be_list_owner
    unless List.exists?(id: params[:id]) && List.find(params[:id]).owner_id == current_user.id
      flash[:error] = "Sorry, but I don't think you're supposed to be there"
      redirect_to(lists_path)
    end
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
end
