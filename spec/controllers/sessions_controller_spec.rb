require 'rails_helper'

describe SessionsController do
  before do
    env = { "omniauth.auth" => OmniAuth.config.mock_auth[:twitter] }
    allow(@controller).to receive(:env).and_return(env)
  end

  describe "#create" do

    it "should successfully create a user" do
      expect {
        post :create
      }.to change{ User.count }.by(1)
    end

    it "should set the session user id" do
      post :create
      expect(User.last.uid).to eq 123
    end

  end

  describe "#destroy" do
    before(:each) do
      user = User.create(access_token: "token", access_secret: "secret")
      session[:user_id] = user.id
    end

    it "should delete session id" do
      expect {
        delete :destroy
      }.to change{ session[:user_id] }.to be nil
    end

    it "should redirect to root path" do
      expect(delete :destroy).to redirect_to(root_path)
    end
  end
end