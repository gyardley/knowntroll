require 'rails_helper'

RSpec.describe ApplicationController, :type => :controller do

  controller do
    before_filter :must_be_logged_in, only: [:new]
    before_filter :must_be_logged_out, only: [:edit]
    before_filter :must_be_list_owner, only: [:show]

    def index
      @current_user = current_user
      render text: 'Index'
    end

    def new
      render text: 'Logged in'
    end

    def edit
      render text: 'Logged out'
    end

    def show
      render text: 'List owner'
    end
  end

  describe "#current_user" do
    before(:each) do
      @user = User.create(access_token: "token", access_secret: "secret")
    end

    it "returns user if session ID set" do
      session[:user_id] = @user.id

      get :index
      expect(assigns(:current_user)).to eq(@user)
    end

    it "returns nil if session ID not set" do
      get :index
      expect(assigns(:current_user)).to eq(nil)
    end
  end

  describe "#must_be_list_owner" do
    it "redirects to lists path if current_user doesn't own the list" do
      @user = User.new(access_token: "token", access_secret: "secret")
      allow(controller).to receive(:current_user).and_return(@user)

      @list =  List.create(name: "B", owner_id: 1337, block_list: [])

      expect(get :show, id: @list.id).to redirect_to(lists_path)
    end

    it "does nothing if current_user owns the list" do
      @user = User.create(access_token: "token", access_secret: "secret")
      allow(controller).to receive(:current_user).and_return(@user)

      @list =  List.create(name: "B", owner_id: @user.id, block_list: [])

      get :show, id: @list.id
      expect(response.body).to include('List owner')
    end
  end

  describe "#must_be_logged_in" do
    it "redirects to root path if current_user is nil" do
      allow(controller).to receive(:current_user).and_return(nil)
      expect(get :new).to redirect_to(root_path)
    end

    it "redirects to root_path if current_user is unauthorized" do
      @user = User.new(access_token: "token", access_secret: "secret")
      allow(controller).to receive(:current_user).and_return(@user)
      allow(@user).to receive(:authorized?).and_return(false)

      expect(get :new).to redirect_to(root_path)
    end

    it "clears the session if current_user is unauthorized" do
      @user = User.new(access_token: "token", access_secret: "secret")
      session[:user_id] = @user.id

      allow(controller).to receive(:current_user).and_return(@user)
      allow(@user).to receive(:authorized?).and_return(false)

      get :new
      expect(session[:user_id]).to be nil
    end

    it "does nothing if current_user" do
      @user = User.new(access_token: "token", access_secret: "secret")
      allow(controller).to receive(:current_user).and_return(@user)

      get :new
      expect(response.body).to include('Logged in')
    end
  end

  describe "#must_be_logged_out" do
    it "redirects to lists path if there's a current user" do
      @user = User.new(access_token: "token", access_secret: "secret")
      allow(controller).to receive(:current_user).and_return(@user)

      expect(get :edit, id: 1).to redirect_to(lists_path)
    end

    it "does nothing if not current_user" do
      allow(controller).to receive(:current_user).and_return(@user)

      get :edit, id: 1
      expect(response.body).to include('Logged out')
    end
  end

end