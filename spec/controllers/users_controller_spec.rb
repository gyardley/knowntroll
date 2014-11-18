require 'rails_helper'

RSpec.describe UsersController, :type => :controller do
  before(:each) do
    allow(controller).to receive(:must_be_logged_in)
    @user = User.create(uid: 1, access_token: "token", access_secret: "secret")
    allow(controller).to receive(:current_user).and_return(@user)
  end

  describe "#email" do
    it "should change email to posted value" do
      expect { post :email, email: "to@me.com" }.to change { @user.email }.to("to@me.com")
    end

    it "should redirect to lists_path" do
      expect(post :email, email: "to@me.com").to redirect_to(lists_path)
    end
  end

  describe "#decline" do
    it "should change decline flag to true" do
      expect { get :decline }.to change { @user.declined }.to(true)
    end

    it "should redirect to lists_path" do
      expect(get :decline).to redirect_to(lists_path)
    end
  end
end